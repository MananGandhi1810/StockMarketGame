import 'package:flutter/material.dart';
import 'package:stockmarketgame/game_page.dart';

class HomePage extends StatefulWidget {
  HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  TextEditingController nameController = TextEditingController();
  TextEditingController roomIdController = TextEditingController();
  bool isNewGame = false;

  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: [
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  validator: (value) =>
                      value!.isEmpty ? 'Please enter your name' : null,
                  decoration: const InputDecoration(
                    labelText: 'Enter your name',
                  ),
                  controller: nameController,
                ),
                Row(
                  children: [
                    Text("New Game"),
                    Spacer(),
                    Switch(
                      value: isNewGame,
                      onChanged: (value) {
                        setState(() {
                          isNewGame = value;
                          roomIdController.clear();
                        });
                      },
                    ),
                  ],
                ),
                !isNewGame
                    ? TextFormField(
                        validator: (value) =>
                            value!.isEmpty ? 'Please enter your room id' : null,
                        decoration: const InputDecoration(
                          labelText: 'Enter your room id',
                        ),
                        controller: roomIdController,
                      )
                    : Container(),
                ElevatedButton(
                  onPressed: () {
                    if(_formKey.currentState!.validate()) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => GamePage(
                              name: nameController.text,
                              roomId: roomIdController.text,
                              isNewGame: isNewGame),
                        ),
                      );
                    }
                  },
                  child: Text('Join Room'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
