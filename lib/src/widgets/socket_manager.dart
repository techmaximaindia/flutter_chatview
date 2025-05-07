/* import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../utils/constants/constants.dart';

class SocketManager {
  static final SocketManager _instance = SocketManager._internal();
  late IO.Socket _socket;

  factory SocketManager() {
    return _instance;
  }

  SocketManager._internal();

  void connectSocket({
    required Function(String incomingText) onMessageReceived,
    required String source,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final String? conversationId = prefs.getString('conversation_id');

     IO.Socket _socket = IO.io(socket_url, <String, dynamic>{
      'autoConnect': false,
      'transports': ['websocket'],
    });

    _socket.connect();

    _socket.onConnect((_) {
      print('Connection established');
      Map<String, dynamic> messageMap = {'id': conversationId, 'from': 'appchatmaxima'};
      _socket.emit('storeClientInfo', messageMap);
    });

    _socket.on('incoming', (newMessage) {
      if (newMessage != null && newMessage['streaming'] == true) {
        if (newMessage['source'] == source) {
          String incomingText = newMessage['answer'];
          onMessageReceived(incomingText); 
        }
      }
    });

    _socket.onDisconnect((_) => print('Socket disconnected'));

    _socket.onConnectError((err) => print('Connection error: $err'));

    _socket.onError((err) => print('Socket error: $err'));
  }

  void disconnectSocket() {
    _socket.disconnect();
    print('Socket disconnected');
  }
}
 */
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../utils/constants/constants.dart';

class SocketManager {
  static final SocketManager _instance = SocketManager._internal();
  late IO.Socket _socket;

  factory SocketManager() {
    return _instance;
  }

  SocketManager._internal();

  void connectSocket({
    required Function(String incomingText) onMessageReceived,
    /* required String source, */
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final String? conversationId = prefs.getString('conversation_id');
    final String? ticketId = prefs.getString('ticket_id');
    String? session_Id; 
    String? page =prefs.getString('page');
    if(page=='ticket'){
      session_Id=ticketId;
    } 
    else{
      session_Id=conversationId;
    }

     IO.Socket _socket = IO.io(socket_url, <String, dynamic>{
      'autoConnect': false,
      'transports': ['websocket'],
    });

    _socket.connect();

    _socket.onConnect((_) {
      print('Connection established');
      Map<String, dynamic> messageMap = {'id': session_Id, 'from': 'appchatmaxima'};
      _socket.emit('storeClientInfo', messageMap);
    });

    _socket.on('incoming', (newMessage) {
      if (newMessage != null && newMessage['streaming'] == true) {
          // newMessage['source'] == 'chat'
        
        if(newMessage['source'] == 'chat'){
          String incomingText = newMessage['answer'];
          onMessageReceived(incomingText);
        }
        else if (newMessage['source_type']=='reply'&& newMessage['source']== 'ticket') {
          String incomingText = newMessage['answer'];
          onMessageReceived(incomingText); 
        }
      }
    });

    _socket.onDisconnect((_) => print('Socket disconnected'));

    _socket.onConnectError((err) => print('Connection error: $err'));

    _socket.onError((err) => print('Socket error: $err'));
  }

  void disconnectSocket() {
    _socket.disconnect();
    print('Socket disconnected');
  }
}
