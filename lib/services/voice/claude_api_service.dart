import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../config.dart';

// ---------------------------------------------------------------------------
// Data models
// ---------------------------------------------------------------------------

class ClaudeMessage {
  final String role;
  final dynamic content; // String or List (tool_use content blocks)
  const ClaudeMessage({required this.role, required this.content});

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

sealed class ClaudeResponse {}

class ClaudeTextResponse extends ClaudeResponse {
  final String text;
  final List<ClaudeMessage> updatedHistory;
  ClaudeTextResponse({required this.text, required this.updatedHistory});
}

class ClaudeToolResponse extends ClaudeResponse {
  final String toolName;
  final Map<String, dynamic> toolInput;
  final String toolUseId;
  final List<ClaudeMessage> updatedHistory;
  ClaudeToolResponse({
    required this.toolName,
    required this.toolInput,
    required this.toolUseId,
    required this.updatedHistory,
  });
}

class ClaudeErrorResponse extends ClaudeResponse {
  final String message;
  ClaudeErrorResponse({required this.message});
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

class ClaudeApiService {
  static const _model = 'claude-haiku-4-5-20251001';
  static const _maxTokens = 400;
  static const _apiUrl = 'https://api.anthropic.com/v1/messages';

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
- If asked something outside your knowledge domain, say so gently and offer to help with something you can do.
- Address users by name if you know it.
''';

  static const List<Map<String, dynamic>> _tools = [
    {
      'name': 'navigate_to',
      'description': 'Navigate to a specific screen in the app.',
      'input_schema': {
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
    {
      'name': 'start_walk',
      'description': 'Start a walking session.',
      'input_schema': {
        'type': 'object',
        'properties': {},
        'required': [],
      },
    },
    {
      'name': 'end_walk',
      'description': 'End the current walking session.',
      'input_schema': {
        'type': 'object',
        'properties': {},
        'required': [],
      },
    },
    {
      'name': 'update_setting',
      'description': 'Update an app setting.',
      'input_schema': {
        'type': 'object',
        'properties': {
          'setting': {
            'type': 'string',
            'enum': ['voice', 'language', 'reminders'],
            'description': 'The setting to update.',
          },
          'value': {
            'type': 'string',
            'description': 'The new value (e.g. "true"/"false" for voice/reminders, language code like "en"/"fr" for language).',
          },
        },
        'required': ['setting', 'value'],
      },
    },
    {
      'name': 'update_profile',
      'description': 'Update a field in the user profile.',
      'input_schema': {
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
    {
      'name': 'call_emergency',
      'description': 'Call the emergency contact.',
      'input_schema': {
        'type': 'object',
        'properties': {},
        'required': [],
      },
    },
  ];

  Future<ClaudeResponse> chat(
    String userText,
    List<ClaudeMessage> history,
  ) async {
    final messages = [
      ...history.map((m) => m.toJson()),
      {'role': 'user', 'content': userText},
    ];

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'x-api-key': claudeApiKey,
          'anthropic-version': '2023-06-01',
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'model': _model,
          'max_tokens': _maxTokens,
          'system': _systemPrompt,
          'tools': _tools,
          'messages': messages,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        return ClaudeErrorResponse(
          message: 'API error ${response.statusCode}: ${response.body}',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final stopReason = data['stop_reason'] as String?;
      final content = data['content'] as List<dynamic>;

      if (stopReason == 'tool_use') {
        // Find the tool_use block
        final toolBlock = content.firstWhere(
          (b) => b['type'] == 'tool_use',
          orElse: () => null,
        );
        if (toolBlock == null) {
          return ClaudeErrorResponse(message: 'Tool use block missing in response.');
        }

        final updatedHistory = [
          ...history,
          ClaudeMessage(role: 'user', content: userText),
          ClaudeMessage(role: 'assistant', content: content),
        ];

        return ClaudeToolResponse(
          toolName: toolBlock['name'] as String,
          toolInput: Map<String, dynamic>.from(toolBlock['input'] as Map),
          toolUseId: toolBlock['id'] as String,
          updatedHistory: updatedHistory,
        );
      } else {
        // Plain text response
        final textBlock = content.firstWhere(
          (b) => b['type'] == 'text',
          orElse: () => null,
        );
        final text = textBlock != null ? (textBlock['text'] as String) : '';

        final updatedHistory = [
          ...history,
          ClaudeMessage(role: 'user', content: userText),
          ClaudeMessage(role: 'assistant', content: text),
        ];

        return ClaudeTextResponse(text: text, updatedHistory: updatedHistory);
      }
    } catch (e) {
      return ClaudeErrorResponse(message: 'Request failed: $e');
    }
  }

  Future<String> sendToolResult(
    String toolUseId,
    String toolResult,
    List<ClaudeMessage> historyWithToolUse,
  ) async {
    final messages = [
      ...historyWithToolUse.map((m) => m.toJson()),
      {
        'role': 'user',
        'content': [
          {
            'type': 'tool_result',
            'tool_use_id': toolUseId,
            'content': toolResult,
          },
        ],
      },
    ];

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'x-api-key': claudeApiKey,
          'anthropic-version': '2023-06-01',
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'model': _model,
          'max_tokens': _maxTokens,
          'system': _systemPrompt,
          'tools': _tools,
          'messages': messages,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        return 'Sorry, I had trouble confirming that action.';
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final content = data['content'] as List<dynamic>;
      final textBlock = content.firstWhere(
        (b) => b['type'] == 'text',
        orElse: () => null,
      );
      return textBlock != null ? (textBlock['text'] as String) : 'Done.';
    } catch (e) {
      return 'Sorry, I had trouble confirming that action.';
    }
  }
}
