import 'package:flutter/services.dart';
import 'package:socket_io_client/socket_io_client.dart';
import 'package:flutter/material.dart';

class GamePage extends StatefulWidget {
  final String name;
  String roomId;
  final bool isNewGame;
  GamePage({
    Key? key,
    required this.name,
    required this.roomId,
    required this.isNewGame,
  }) : super(key: key);

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  var serverUrl = 'SERVERURL';
  late var socket;
  bool roomDoesNotExist = false;
  late var playersInRoom = [];
  var hasGameStarted = false;
  var thisPlayer;
  var _index = 0;
  var gameStartedBeforeJoin = false;
  var stockPrices = [];
  var buyOrSell = 'Buy';
  var buyOrSellAmount = 0;
  var buyOrSellStockName = 'Wockhardt';
  var hasLoanStockMatureCard = false;
  bool isSocketConnectionLoading = false;
  var roundOver = false;
  final buyOrSellFormKey = GlobalKey<FormState>();
  var gameLog = [];
  late var dashboardData;

  void initSocket() {
    setState(() {
      thisPlayer = {
        'name': widget.name,
        'roomId': widget.roomId,
        'isHost': false,
        'cards': [],
        'money': 1000000,
        'chancesPlayed': 0,
      };
    });
    socket = io(
      '$serverUrl',
      <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
        'forceNew': true,
      },
    );
    socket.connect();
    isSocketConnectionLoading = true;
    socket.on('connect', (data) {
      isSocketConnectionLoading = false;
      if (!widget.isNewGame) {
        socket.emit('joinGame', {
          'name': widget.name,
          'roomId': widget.roomId,
        });
      } else {
        socket.emit('newGame', {
          'name': widget.name,
          'roomId': widget.roomId,
        });
      }
      socket.emit('whoami');
    });
    socket.on('newPlayer', (data) {
      debugPrint("newPlayer: $data");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("${data['name']} joined the game"),
      ));
    });
    socket.on('playerLeave', (data) {
      debugPrint("playerLeave: $data");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("${data['name']} left the game"),
      ));
    });
    socket.on('roomId', (data) {
      setState(() {
        widget.roomId = data['roomId'];
      });
      debugPrint("roomId: $data");
    });
    socket.on("noRoomError", (data) {
      setState(() {
        roomDoesNotExist = true;
      });
      roomErrorDialog(context, 'This room does not exist', true);
    });
    socket.on('playerListChange', (data) {
      socket.emit('whoami');
      setState(() {
        playersInRoom = data['players'];
      });
      debugPrint("playerListChange: ${data['players']}");
    });
    socket.on('whoamiAnswer', (data) {
      setState(() {
        thisPlayer = data['player'];
        try {
          if (thisPlayer['cards'].firstWhere(
                  (card) => card['shareName'] == 'Loan Stock Mature') !=
              null) {
            hasLoanStockMatureCard = true;
          } else {
            hasLoanStockMatureCard = false;
          }
        } catch (e) {
          hasLoanStockMatureCard = false;
        }
      });
      debugPrint("whoamiAnswer: ${data['player']}");
    });
    socket.on('gameStarted', (data) {
      setState(() {
        hasGameStarted = true;
      });
      socket.emit('whoami');
    });
    socket.on('gameStartedError', (data) {
      gameStartedBeforeJoin = true;
      roomErrorDialog(context, 'Game already started', true);
    });
    socket.on('yourCards', (data) {
      setState(() {
        thisPlayer['cards'] = data['cards'];
        try {
          if (thisPlayer['cards'].firstWhere(
                  (card) => card['shareName'] == 'Loan Stock Mature') !=
              null) {
            hasLoanStockMatureCard = true;
          } else {
            hasLoanStockMatureCard = false;
          }
        } catch (e) {
          hasLoanStockMatureCard = false;
        }
      });
      socket.emit('whoami');
    });
    socket.on('stockPrices', (data) {
      setState(() {
        stockPrices = data['prices'];
      });
      debugPrint("stockPrices: ${data}");
      socket.emit('whoami');
    });
    socket.on('buyOrSellStockError', (data) {
      debugPrint("buyOrSellStockError: ${data}");
      roomErrorDialog(context, data, false);
    });
    socket.on('actionResponse', (data) {
      // ScaffoldMessenger.of(context)
      //     .showSnackBar(SnackBar(content: Text("${data['action']})")));
      setState(() {
        gameLog.add(data['action']);
      });
      socket.emit('whoami');
    });
    socket.on('actionResponseError', (data) {
      debugPrint("actionResponseError: ${data}");
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("${data['action']})")));
      socket.emit('whoami');
    });
    socket.on('roundOver', (data) {
      if (data == null) {
        roundOver = true;
        if (thisPlayer['isHost']) {
          showRoundOverDialog(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  "Round Over. Please wait for the host to start the next round"),
            ),
          );
        }
      } else {
        if (thisPlayer['isHost']) {
          showRoundOverDialog(context);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data),
          ),
        );
      }
    });
    socket.on('newRoundStarted', (_) {
      setState(() {
        roundOver = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              "A new round has started. New cards have been distributed to you."),
        ),
      );
      socket.emit('whoami');
    });
    socket.on("stockPricesChange", (data) {
      setState(() {
        stockPrices = data['prices'];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Stock prices have been updated for the next round."),
        ),
      );
      showStockPricesDialog(context, true);
      socket.emit('whoami');
    });
    socket.on('yourScore', (data) {
      setState(() {
        thisPlayer['totalScore'] = data['yourScore'];
      });
      showScoreDialog(thisPlayer['totalScore']);
      socket.emit('whoami');
    });
    socket.on('winnerListResponse', (data) {
      showWinnerListDialog(context, data['winnerList']);
    });
    socket.on('dashboardChanges', (data) {
      debugPrint("dashboardChanges: ${data['stockActions']['Buy']}");
      setState(() {
        dashboardData = data['stockActions'];
      });
      socket.emit('whoami');
    });
    socket.on("currencyChange", (data) {
      setState(() {
        thisPlayer['money'] = data['money'];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              "Currency has been changed by ${data['perChange']}%. Your new balance is ₹${thisPlayer['money']}"),
        ),
      );
      socket.emit('whoami');
    });
  }

  @override
  void initState() {
    super.initState();
    initSocket();
  }

  @override
  void dispose() {
    socket.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: IconButton(
        icon: Icon(Icons.book),
        onPressed: () => showGameLogDialog(context),
      ),
      appBar: AppBar(
        title: Text('Game Page'),
        actions: [
          hasGameStarted
              ? IconButton(
                  onPressed: () {
                    showDashBoardDialog(context);
                  },
                  icon: Icon(Icons.dashboard))
              : Container()
        ],
      ),
      body: SingleChildScrollView(
        child: !roomDoesNotExist &&
                !gameStartedBeforeJoin &&
                !isSocketConnectionLoading
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Text(
                      'Hello ${widget.name}, your room id is ${widget.roomId}',
                      style: TextStyle(fontSize: 20),
                    ),
                    Text("Players in room: ${playersInRoom.length}"),
                    ConstrainedBox(
                      constraints:
                          BoxConstraints(minHeight: 20, maxHeight: 200),
                      child: Scrollbar(
                        child: ListView.builder(
                          scrollDirection: Axis.vertical,
                          shrinkWrap: true,
                          itemCount: playersInRoom.length,
                          itemBuilder: (context, index) {
                            return ListTile(
                              title: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      "${playersInRoom[index]['username'].toString()} ${playersInRoom[index]['isHost'] ? '(Host)' : ''}"),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  hasGameStarted
                                      ? Text(
                                          'Money: ₹${playersInRoom[index]['money']}, Chances left: ${3 - playersInRoom[index]['chancesPlayed']}')
                                      : Container(),
                                ],
                              ),
                              trailing: hasGameStarted
                                  ? IconButton(
                                      icon: Icon(Icons.menu),
                                      onPressed: () {
                                        showPlayerPortfolioDialog(
                                            context, playersInRoom[index]);
                                      },
                                    )
                                  : Icon(null),
                            );
                          },
                        ),
                      ),
                    ),
                    !hasGameStarted &&
                            thisPlayer['isHost'] &&
                            playersInRoom.length > 1
                        ? ElevatedButton(
                            child: Text('Start Game'),
                            onPressed: () {
                              socket
                                  .emit('startGame', {'roomId': widget.roomId});
                            },
                          )
                        : hasGameStarted
                            ? Text(
                                'Game has started, you have ₹${thisPlayer['money']} and ${3 - thisPlayer['chancesPlayed']} chances')
                            : playersInRoom.length > 1
                                ? Text('Game has not started')
                                : Text('Waiting for players'),
                    hasGameStarted &&
                            thisPlayer['cards'] != [] &&
                            thisPlayer['cards'] != null
                        ? Column(
                            children: [
                              thisPlayer['isHost']
                                  ? Column(
                                      children: [
                                        Text("You are the host"),
                                        ElevatedButton(
                                            onPressed: () {
                                              showEndRoundDialog(context);
                                            },
                                            child: Text("End Round"))
                                      ],
                                    )
                                  : Container(),
                              SizedBox(
                                height: 200, // card height
                                child: PageView.builder(
                                  itemCount: thisPlayer['cards'].length,
                                  controller:
                                      PageController(viewportFraction: 0.7),
                                  onPageChanged: (int index) =>
                                      setState(() => _index = index),
                                  itemBuilder: (_, i) {
                                    return Transform.scale(
                                      scale: i == _index ? 1 : 0.9,
                                      child: Card(
                                        elevation: 6,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Center(
                                          child: Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Center(
                                              child: Column(
                                                children: [
                                                  Text(
                                                    "${thisPlayer['cards'][i]['shareName']}",
                                                    style: const TextStyle(
                                                        fontSize: 18,
                                                        fontWeight:
                                                            FontWeight.bold),
                                                  ),
                                                  const Padding(
                                                    padding:
                                                        EdgeInsets.all(8.0),
                                                  ),
                                                  Text(
                                                    "${thisPlayer['cards'][i]['change']}",
                                                    style: const TextStyle(
                                                        fontSize: 16),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          )
                        : Container(),
                    hasGameStarted &&
                            thisPlayer['cards'] != [] &&
                            thisPlayer['cards'] != null
                        ? Column(
                            children: [
                              ElevatedButton(
                                onPressed: () {
                                  showStockPricesDialog(context, false);
                                },
                                child: Text('View Stock Prices'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  if (thisPlayer['chancesPlayed'] < 3) {
                                    showBuySellActionDialog(context);
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'You have used all your chances for this round.'),
                                      ),
                                    );
                                  }
                                },
                                child: Text('Buy/Sell'),
                              ),
                              hasLoanStockMatureCard &&
                                      hasLoanStockMatureCard != null
                                  ? ElevatedButton(
                                      onPressed: () {
                                        if (thisPlayer['chancesPlayed'] < 3) {
                                          showLoanStockMatureDialog(context);
                                        } else {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                  'You have used all your chances for this round.'),
                                            ),
                                          );
                                        }
                                      },
                                      child: Text('Loan Stock Mature'),
                                    )
                                  : Container(),
                            ],
                          )
                        : Container()
                  ],
                ),
              )
            : isSocketConnectionLoading
                ? Center(
                    child: CircularProgressIndicator(),
                  )
                : Container(),
      ),
    );
  }

  roomErrorDialog(BuildContext context, String message, bool popAfterShowing) {
    return showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(message),
            actions: [
              TextButton(
                child: Text("Close"),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              )
            ],
          );
        }).then((_) => popAfterShowing ? Navigator.pop(context) : null);
  }

  showStockPricesDialog(BuildContext context, bool newPrices) {
    return showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('${newPrices ? "New " : ""}Stock Prices'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                    '${stockPrices[0]['name']}: ₹${stockPrices[0]['price']}\n'),
                Text(
                    '${stockPrices[1]['name']}: ₹${stockPrices[1]['price']}\n'),
                Text(
                    '${stockPrices[2]['name']}: ₹${stockPrices[2]['price']}\n'),
                Text(
                    '${stockPrices[3]['name']}: ₹${stockPrices[3]['price']}\n'),
                Text(
                    '${stockPrices[4]['name']}: ₹${stockPrices[4]['price']}\n'),
                Text('${stockPrices[5]['name']}: ₹${stockPrices[5]['price']}'),
              ],
            ),
            actions: [
              TextButton(
                child: Text("Close"),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              )
            ],
          );
        });
  }

  showBuySellActionDialog(BuildContext context) {
    var actions = ["Buy", "Sell"];
    var stockNames = stockPrices.map((e) => e['name']).toList();
    return showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Buy/Sell'),
            content: Form(
              key: buyOrSellFormKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Select the action you want to perform'),
                  DropdownButtonFormField(
                    value: buyOrSell,
                    items: actions
                        .map((label) => DropdownMenuItem(
                              child: new Text(label),
                              value: label,
                            ))
                        .toList(),
                    onChanged: (buyOrSellDropdownValue) {
                      debugPrint(buyOrSellDropdownValue.toString());
                      buyOrSell = buyOrSellDropdownValue.toString();
                      setState(() {
                        buyOrSell;
                      });
                    },
                    onSaved: (buyOrSellDropdownValue) {
                      debugPrint(buyOrSellDropdownValue.toString());
                      buyOrSell = buyOrSellDropdownValue.toString();
                      setState(() {
                        buyOrSell;
                      });
                    },
                  ),
                  DropdownButtonFormField(
                    value: buyOrSellStockName,
                    items: stockNames
                        .map((label) => DropdownMenuItem(
                              child: new Text(label),
                              value: label,
                            ))
                        .toList(),
                    onChanged: (buyOrSellStockNameDropdownValue) {
                      setState(() {
                        buyOrSellStockName =
                            buyOrSellStockNameDropdownValue.toString();
                      });
                      debugPrint(
                        buyOrSellStockNameDropdownValue.toString(),
                      );
                    },
                    onSaved: (buyOrSellStockNameDropdownValue) {
                      setState(() {
                        buyOrSellStockName =
                            buyOrSellStockNameDropdownValue.toString();
                      });
                    },
                  ),
                  TextFormField(
                    validator: (value) => value!.isEmpty || value == null
                        ? 'Please enter the amount you want to ${buyOrSell}'
                        : null,
                    decoration: InputDecoration(
                      labelText: 'Enter the amount you want to ${buyOrSell}',
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    keyboardType: TextInputType.number,
                    onChanged: (String? value) {
                      debugPrint(value);
                      setState(() {
                        buyOrSellAmount = int.parse(value!);
                      });
                    },
                    onSaved: (String? value) {
                      debugPrint(value);
                      setState(() {
                        buyOrSellAmount = int.parse(value!);
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () {
                  if (buyOrSellFormKey.currentState!.validate()) {
                    Navigator.of(context).pop();
                    buyOrSellStock(
                        buyOrSell, buyOrSellStockName, buyOrSellAmount);
                  }
                },
                child: Text("Submit"),
              )
            ],
          );
        });
  }

  void buyOrSellStock(String action, String stock, int amount) {
    socket.emit('buyOrSellStock', {
      'action': action,
      'stock': stock,
      'amount': amount,
    });
  }

  showLoanStockMatureDialog(BuildContext context) {
    return showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Claim Loan Stock Mature?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                    'Do you want to claim Loan Stock Mature? You will get ₹100000.'),
              ],
            ),
            actions: [
              TextButton(
                child: Text("Close"),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  claimLoanStockMature();
                },
                child: Text("Yes, Claim"),
              )
            ],
          );
        });
  }

  void claimLoanStockMature() {
    socket.emit('claimLoanStockMature');
  }

  showPlayerPortfolioDialog(BuildContext context, currentPlayer) {
    var playerBoughtShares = currentPlayer['boughtStocks']
        .entries
        .map((entry) => {"name": entry.key, "amount": entry.value})
        .toList();
    debugPrint(playerBoughtShares.toString());
    return showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Player Portfolio'),
            content: Container(
              width: double.maxFinite,
              child: playerBoughtShares != []
                  ? ListView.builder(
                      shrinkWrap: true,
                      itemCount: playerBoughtShares.length,
                      itemBuilder: (context, index) {
                        return Text(
                            "${playerBoughtShares[index]['name']}: ${playerBoughtShares[index]['amount']} shares");
                      },
                    )
                  : Text(
                      "${currentPlayer['username']} has not bought any stocks yet."),
            ),
            actions: [
              TextButton(
                child: Text("Close"),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              )
            ],
          );
        });
  }

  showRoundOverDialog(BuildContext context) {
    return showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Round Over'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'This round has ended. All players have played their chances. Do you want to start the next round?',
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text("No, End Game"),
              onPressed: () {
                Navigator.of(context).pop();
                socket.emit("endGame");
              },
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                socket.emit('startNextRound');
              },
              child: Text("Yes, Start the Next Round"),
            )
          ],
        );
      },
    );
  }

  showScoreDialog(score) {
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Score'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'The game has ended. You have a total balance of ₹${score}. Click ok to see the scoreboard.',
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text("Ok"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            )
          ],
        );
      },
    ).then((value) {
      socket.emit('winnerList');
    });
  }

  showWinnerListDialog(BuildContext context, winnerList) {
    return showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Scoreboard'),
          content: Container(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListView.builder(
                  shrinkWrap: true,
                  itemCount: winnerList.length,
                  itemBuilder: (BuildContext context, int index) {
                    return ListTile(
                      title: Text(
                        '${index + 1}. ${winnerList[index]['username']} with a total balance of ₹${winnerList[index]['totalScore']}',
                        style: TextStyle(fontSize: 20),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text("Ok, Close Game"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            )
          ],
        );
      },
    ).then((_) {
      Navigator.of(context).pop();
    });
  }

  showGameLogDialog(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Game Log'),
          content: Container(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListView.builder(
                  shrinkWrap: true,
                  itemCount: gameLog.length,
                  itemBuilder: (BuildContext context, int index) {
                    return ListTile(
                      title: Text("${gameLog[index]}"),
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text("Ok"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            )
          ],
        );
      },
    );
  }

  showEndRoundDialog(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('End Round?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Do you really want to end the round? All playes may not have played their chances yet.',
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text("Close"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                socket.emit('endRoundByHost');
              },
              child: Text("Yes, End Round"),
            )
          ],
        );
      },
    );
  }

  showDashBoardDialog(BuildContext context) {
    var dashboardDataBuy = dashboardData['Buy']!
        .entries
        .map((entry) => {"stock": entry.key, "amount": entry.value})
        .toList();
    var dashboardDataSell = dashboardData['Sell']!
        .entries
        .map((entry) => {"stock": entry.key, "amount": entry.value})
        .toList();
    debugPrint("dashboardDataBuy: ${dashboardData["Buy"]}");
    debugPrint("dashboardDataSell: ${dashboardData["Sell"]}");
    return showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Dashboard'),
            content: Container(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Players have bought:"),
                    ListView.builder(
                      shrinkWrap: true,
                      itemCount: dashboardDataBuy.length,
                      itemBuilder: (BuildContext context, int index) {
                        return ListTile(
                          title: Text(
                              "${dashboardDataBuy[index]["stock"]}: ${dashboardDataBuy[index]["amount"]}"),
                        );
                      },
                    ),
                    Text("Players have sold:"),
                    ListView.builder(
                      shrinkWrap: true,
                      itemCount: dashboardDataSell.length,
                      itemBuilder: (BuildContext context, int index) {
                        return ListTile(
                          title: Text(
                              "${dashboardDataSell[index]["stock"]}: ${dashboardDataSell[index]["amount"]}"),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                child: Text("Ok"),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              )
            ],
          );
        });
  }
}
