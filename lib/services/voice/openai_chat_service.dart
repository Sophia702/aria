import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../config.dart';

// ---------------------------------------------------------------------------
// Result types
// ---------------------------------------------------------------------------

sealed class ChatResult {}

/// A plain spoken reply. [assistantMessage] is appended to history verbatim.
class ChatTextResult extends ChatResult {
  final String text;
  final Map<String, dynamic> assistantMessage;
  ChatTextResult(this.text, this.assistantMessage);
}

/// The model wants to run an app action (navigate, start walk, save a setting…).
class ChatToolResult extends ChatResult {
  final String toolName;
  final Map<String, dynamic> toolArgs;
  final String toolCallId;
  final Map<String, dynamic> assistantMessage; // assistant turn carrying tool_calls
  ChatToolResult({
    required this.toolName,
    required this.toolArgs,
    required this.toolCallId,
    required this.assistantMessage,
  });
}

class ChatErrorResult extends ChatResult {
  final String message;
  ChatErrorResult(this.message);
}

// ---------------------------------------------------------------------------
// Service — OpenAI Chat Completions with function calling.
// ---------------------------------------------------------------------------

/// aria's "brain": understands what the user said and either replies in plain
/// language or calls one of the app-action tools (navigate, start/end walk,
/// update a setting or profile field, call emergency). Powered by OpenAI so it
/// works hands-free end to end.
class OpenAiChatService {
  static const _model = 'gpt-4o-mini';
  static const _maxTokens = 400;
  static const _apiUrl = 'https://api.openai.com/v1/chat/completions';

  static const _systemPrompt = '''
You are aria, a warm and knowledgeable voice assistant built into a Parkinson's gait-assist app for older adults.

Your role:
- Help users navigate the app (Home, Progress, Profile, Settings screens)
- Start and end walking sessions
- Update app settings (voice assistance, language, reminders)
- Update user profile information (name, age, medications, clinician, emergency contact)
- Call emergency contacts when requested
- Answer questions about Parkinson's disease, freezing of gait, and the app's features

Rules:
- Keep responses under 2 sentences. Be warm, calm, and encouraging.
- Never use markdown formatting — plain spoken language only.
- Always confirm completed actions clearly.
- When the user asks to do something the app supports, call the matching tool rather than only describing it.
- If asked something outside your knowledge domain, say so gently and offer to help with something you can do.
- Address users by name if you know it.
''';

  /// OpenAI function-calling tool definitions. JSON-schema `parameters` mirror
  /// the in-app actions the voice controller knows how to execute.
  static const List<Map<String, dynamic>> _tools = [
    {
      'type': 'function',
      'function': {
        'name': 'navigate_to',
        'description': 'Navigate to a specific screen in the app.',
        'parameters': {
          'type': 'object',
          'properties': {
            'screen': {
              'type': 'string',
              'enum': ['home', 'progress', 'profile', 'settings'],
              'description': 'The screen to navigate to.',
            },
            'screenIndex': {
              'type': 'integer',
              'description': 'Tab index: home=0, progress=1, profile=2, settings=3.',
            },
          },
          'required': ['screen', 'screenIndex'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'start_walk',
        'description': 'Start a walking session.',
        'parameters': {'type': 'object', 'properties': {}, 'required': []},
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'end_walk',
        'description': 'End the current walking session.',
        'parameters': {'type': 'object', 'properties': {}, 'required': []},
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'update_setting',
        'description': 'Update an app setting.',
        'parameters': {
          'type': 'object',
          'properties': {
            'setting': {
              'type': 'string',
              'enum': ['voice', 'language', 'reminders'],
              'description': 'The setting to update.',
            },
            'value': {
              'type': 'string',
              'description':
                  'The new value (e.g. "true"/"false" for voice/reminders, language code like "en"/"fr" for language).',
            },
          },
          'required': ['setting', 'value'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'update_profile',
        'description': 'Update a field in the user profile.',
        'parameters': {
          'type': 'object',
          'properties': {
            'field': {
              'type': 'string',
              'enum': ['name', 'age', 'meds', 'clinician', 'contactType', 'contactName', 'contactPhone'],
              'description': 'The profile field to update.',
            },
            'value': {
              'type': 'string',
              'description': 'The new value for the field.',
            },
          },
          'required': ['field', 'value'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'call_emergency',
        'description': 'Call the emergency contact.',
        'parameters': {'type': 'object', 'properties': {}, 'required': []},
      },
    },
  ];

  /// Send the running conversation (already including the latest user turn) and
  /// get back either spoken text or a tool call to execute.
  Future<ChatResult> send(List<Map<String, dynamic>> history) async {
    final messages = [
      {'role': 'system', 'content': _systemPrompt},
      ...history,
    ];

    try {
      final response = await http
          .post(
            Uri.parse(_apiUrl),
            headers: {
              'Authorization': 'Bearer $openAiApiKey',
              'content-type': 'application/json',
            },
            body: jsonEncode({
              'model': _model,
              'max_tokens': _maxTokens,
              'messages': messages,
              'tools': _tools,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        return ChatErrorResult('API error ${response.statusCode}: ${response.body}');
      }

      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final choice = (data['choices'] as List).first as Map<String, dynamic>;
      final msg = choice['message'] as Map<String, dynamic>;
      final toolCalls = msg['tool_calls'] as List?;

      if (toolCalls != null && toolCalls.isNotEmpty) {
        final call = toolCalls.first as Map<String, dynamic>;
        final fn = call['function'] as Map<String, dynamic>;
        return ChatToolResult(
          toolName: fn['name'] as String,
          toolArgs: _parseArgs(fn['arguments']),
          toolCallId: call['id'] as String,
          // Echo the assistant turn back verbatim so the follow-up request is valid.
          assistantMessage: {
            'role': 'assistant',
            'content': msg['content'],
            'tool_calls': toolCalls,
          },
        );
      }

      final text = (msg['content'] as String?)?.trim() ?? '';
      return ChatTextResult(text, {'role': 'assistant', 'content': text});
    } catch (e) {
      return ChatErrorResult('Request failed: $e');
    }
  }

  /// OpenAI returns function arguments as a JSON string — decode defensively.
  static Map<String, dynamic> _parseArgs(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {/* fall through */}
    }
    return <String, dynamic>{};
  }
}
