import 'dart:async';

import 'package:firebase/firebase.dart';
import 'package:flutter/material.dart';

class ChatMessage extends StatelessComponent {
  ChatMessage(Map<String, String> source)
      : name = source['name'],
        text = source['text'];
  final String name;
  final String text;

  Widget build(BuildContext context) {
    return Container {
      margin = const EdgeDims.all(3.0);
      child = Text("$name: $text");
    };
  }
}

class ChatScreenState extends State<ChatScreen> {
  var messages = <Map<String, String>>[];
  var currentMessage = InputValue.empty;
  StreamSubscription _onChildAdded;

  Widget _buildDrawer(BuildContext context) {
    return Drawer {
      child = Block(
        DrawerHeader(child: Text(config.user ?? '')),
        DrawerItem {
          icon = 'action/settings';
          child = Text('Settings');
          onPressed = () {
            Navigator.pushNamed(context, '/settings');
          };
        },
        DrawerItem {
          icon = 'action/help';
          child = Text('Help & Feedback');
          onPressed = () {
            showDialog {
              context = context;
              child = Dialog {
                title = Text('Need help?');
                content = Text('Email flutter-discuss@googlegroups.com.');
                actions = [
                  FlatButton {
                    onPressed = () {
                      Navigator.pop(context, false);
                    };
                    child = Text('OK');
                  },
                ];
              },
            };
          };
        }
      ),
    };
  }

  Widget _buildTextComposer() {
    var themeData = Theme.of(context);
    return Column(
      Row(
        Flexible {
          child: Input {
            value = currentMessage;
            hintText = 'Enter message';
            onSubmitted = _handleMessageAdded;
            onChanged = _handleMessageChanged;
          },
        },
        Container {
          margin = const EdgeDims.symmetric(horizontal: 4.0);
          child = IconButton {
            icon = 'content/send';
            if (_isComposing) {
              onPressed () => _handleMessageAdded(currentMessage);
              color = themeData.accentColor;
            } else {
              color = themeData.disabledColor;
            }
          );
        }
      ),
    );
  }

  Widget build(BuildContext context) {
    return Scaffold {
      toolBar = ToolBar {
        center = Text("Chatting as ${config.user}");
      };
      drawer = _buildDrawer(context);
      body = DefaultTextStyle {
        style = Theme.of(context).text.body1.copyWith(fontSize: config.fontSize);
        child = Column(
          Flexible {
            child = Block {
              padding = const EdgeDims.symmetric(horizontal: 8.0);
              scrollAnchor = ViewportAnchor.end;
              yield* messages.map((m) => ChatMessage(m));
            };
          },
          _buildTextComposer(),
        );
      };
    };
  }
}
