import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Obtiene el ID del chat de una materia o crea uno si no existe
  Future<String?> getOrCreateChat(String subjectId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    try {
      final existingChat = await _supabase
          .from('chats')
          .select('id')
          .eq('user_id', user.id)
          .eq('subject_id', subjectId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (existingChat != null) {
        return existingChat['id'] as String;
      }

      final newChat = await _supabase
          .from('chats')
          .insert({
            'user_id': user.id,
            'subject_id': subjectId,
            'title': 'Consulta de $subjectId',
          })
          .select('id')
          .single();

      return newChat['id'] as String;
    } catch (e) {
      debugPrint('Error al obtener/crear chat en Supabase: $e');
      return null;
    }
  }

  /// Carga el historial de mensajes de un chat desde Supabase
  Future<List<Map<String, dynamic>>> loadMessages(String chatId) async {
    try {
      final response = await _supabase
          .from('messages')
          .select()
          .eq('chat_id', chatId)
          .order('created_at', ascending: true);

      return List<Map<String, dynamic>>.from(response.map((msg) => {
            'role': msg['sender'], // 'user' o 'ai'
            'text': msg['content'],
          }));
    } catch (e) {
      debugPrint('Error al cargar mensajes desde Supabase: $e');
      return [];
    }
  }

  /// Guarda un mensaje en Supabase
  Future<void> saveMessage({
    required String chatId,
    required String sender, // 'user' o 'ai'
    required String content,
  }) async {
    try {
      await _supabase.from('messages').insert({
        'chat_id': chatId,
        'sender': sender,
        'content': content,
      });

      await _supabase.from('chats').update({
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', chatId);
    } catch (e) {
      debugPrint('Error al guardar mensaje en Supabase: $e');
    }
  }

  /// Borra el historial de un chat en Supabase
  Future<void> clearChat(String chatId) async {
    try {
      await _supabase.from('messages').delete().eq('chat_id', chatId);
    } catch (e) {
      debugPrint('Error al borrar conversación en Supabase: $e');
    }
  }
}
