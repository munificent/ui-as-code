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
    return <Container margin=const EdgeDims.all(3.0)>
      Text("$name: $text")
    </Container>;
  }
}

class ChatScreenState extends State<ChatScreen> {
  var messages = <Map<String, String>>[];
  var currentMessage = InputValue.empty;
  StreamSubscription _onChildAdded;

  Widget _buildDrawer(BuildContext context) {
    return <Drawer>
      <Block>
        <DrawerHeader>Text(config.user ?? '')</DrawerHeader>
        <DrawerItem
          icon='action/settings'
          onPressed() {
            Navigator.pushNamed(context, '/settings');
          }
        >
          Text('Settings')
        </DrawerItem>
        <DrawerItem
          icon='action/help'
          onPressed() {
            <showDialog context=context>
              <Dialog
                title=Text('Need help?')
                content=Text('Email flutter-discuss@googlegroups.com.')
                actions=[
                  <FlatButton
                    onPressed() {
                      Navigator.pop(context, false);
                    }
                  >
                    Text('OK')
                  </FlatButton>
                ]
              />
            </showDialog>;
          }
        >
          Text('Help & Feedback')
        </DrawerItem>
      </Block>
    </Drawer>;
  }

  Widget _buildTextComposer() {
    return <Column>
      <Row>
        <Flexible>
          <Input
            value=currentMessage
            hintText='Enter message'
            onSubmitted=_handleMessageAdded
            onChanged=_handleMessageChanged
          />
        </Flexible>
        <Container margin=const EdgeDims.symmetric(horizontal: 4.0)>
          <IconButton
            icon='content/send'
            if (_isComposing) {
              onPressed() => _handleMessageAdded(currentMessage)
              color=Theme.of(context).accentColor
            } else {
              color=Theme.of(context).disabledColor
            }
          />
        </Container>
      </Row>
    </Column>;
  }

  Widget build(BuildContext context) {
    return <Scaffold
      toolBar=<ToolBar center=Text("Chatting as ${config.user}" />
      drawer=_buildDrawer(context)
      body=<DefaultTextStyle
        style=Theme.of(context).text.body1.copyWith(fontSize: config.fontSize)
      >
        <Column>
          <Flexible>
            <Block
              padding=const EdgeDims.symmetric(horizontal: 8.0)
              scrollAnchor=ViewportAnchor.end
            >
              for (var message in messages) ChatMessage(m)
            </Block>
          </Flexible>
          _buildTextComposer()
        </Column>
      </DefaultTextStyle>
    />;
  }
}
