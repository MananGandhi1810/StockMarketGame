const httpServer = require('http').createServer()
const io = require('socket.io')(httpServer)
const cards = require('./cards.json')
const prices = require('./prices.json')

var rooms = {}
var roomIds = []
var users = {}
var gamePrices = {}
var stockActions = {}

io.on('connection', function (client) {
  console.log('Connected...', client.id)

  client.on('message', function name (data) {
    // console.log(data)
    io.emit('message', data)
  })

  client.on('disconnect', function () {
    console.log('Disconnected...', client.id)
    var user = users[client.id]
    try {
      client.leave(user.roomId)
      var index = rooms[user.roomId]['players'].findIndex(
        player => player.id === client.id
      )
      // console.log(rooms[user.roomId]['players'], index)
      rooms[user.roomId]['players'].splice(index, 1)
      users[client.id] = undefined
      if (rooms[user.roomId]['players'].length < 1) {
        delete rooms[user.roomId]
        roomIds.splice(roomIds.indexOf(user.roomId), 1)
      } else {
        if (user.isHost) {
          rooms[user.roomId]['players'][0].isHost = true
        }
        io.to(user.roomId).emit('playerLeave', { name: user.username })
        // console.log('user left:', user.username)
        io.to(user.roomId).emit('playerListChange', {
          players: rooms[user.roomId]['players']
        })
      }
    } catch (e) {
      if (user !== undefined) {
        console.log(e)
      }
    }
  })

  client.on('error', function (err) {
    console.log('Error detected', client.id)
    console.log(err)
  })

  client.on('whoami', function () {
    var user = users[client.id]
    // console.log('user: ', user)
    io.to(client.id).emit('whoamiAnswer', { player: user })
  })

  client.on('startNextRound', function () {
    var user = users[client.id]
    console.log('startNextRound')
    rooms[user.roomId]['roundOver'] = false
    io.to(user.roomId).emit('newRoundStarted')
    rooms[user.roomId]['players'].forEach(player => {
      player['chancesPlayed'] = 0
    })
    changeStockPrices(user.roomId, true)
  })

  client.on('newGame', function (data) {
    var username = data.name
    var roomId = Math.floor(Math.random() * 10000).toString()
    io.to(roomId).emit('dashboardChanges', {
      stockActions: stockActions[roomId]
    })
    // console.log('New game created for ' + username + ' in room ' + roomId)
    // console.log('New game requested', client.id)
    client.join(roomId)
    roomIds.push(roomId)
    gamePrices[roomId] = prices
    rooms[roomId] = {
      gameStarted: false,
      totalRounds: 0,
      players: [],
      allPlayersPlayed: false,
      roundOver: false
    }
    stockActions[roomId] = { Buy: {}, Sell: {} }
    rooms[roomId]['players'] = [
      {
        username: username,
        id: client.id,
        isHost: true,
        cards: [],
        money: 600000,
        chancesPlayed: 0,
        boughtStocks: {}
      }
    ]
    users[client.id] = {
      username: username,
      roomId: roomId,
      isHost: true,
      cards: [],
      money: 600000,
      chancesPlayed: 0,
      boughtStocks: {}
    }
    io.to(data.roomId).emit('stockPrices', {
      prices: gamePrices[data.roomId]
    })
    io.to(roomId).emit('roomId', { roomId: roomId })
    io.to(roomId).emit('playerListChange', {
      players: rooms[roomId]['players']
    })
  })

  client.on('joinGame', function (data) {
    var username = data.name
    var roomId = data.roomId
    io.to(roomId).emit('dashboardChanges', {
      stockActions: stockActions[roomId]
    })
    if (roomIds.includes(roomId)) {
      if (!rooms[roomId]['gameStarted']) {
        try {
          rooms[roomId]['players'].push({
            username: username,
            id: client.id,
            isHost: false,
            cards: [],
            money: 600000,
            chancesPlayed: 0,
            boughtStocks: {}
          })
          users[client.id] = {
            username: username,
            roomId: roomId,
            isHost: false,
            cards: [],
            money: 600000,
            chancesPlayed: 0,
            boughtStocks: {}
          }
          client.join(roomId)
          io.to(roomId).emit('roomId', { roomId: roomId })
          io.to(roomId).emit('newPlayer', { name: username, id: client.id })
          // console.log(rooms[roomId]['players'])
          io.to(roomId).emit('playerListChange', {
            players: rooms[roomId]['players']
          })
          io.to(data.roomId).emit('stockPrices', {
            prices: gamePrices[data.roomId]
          })
        } catch (err) {
          console.log(err)
        }
      } else {
        io.to(client.id).emit('gameStartedError', 'Game already started')
      }
    } else {
      io.to(client.id).emit('noRoomError', 'Game does not exist')
    }
  })
  client.on('startGame', function (data) {
    // console.log(data)
    rooms[data.roomId]['gameStarted'] = true
    io.to(data.roomId).emit('gameStarted')
    io.to(data.roomId).emit('stockPrices', { prices: gamePrices[data.roomId] })
    distributeCards(data.roomId)
  })
  client.on('buyOrSellStock', function (data) {
    var user = users[client.id]
    var roomId = user.roomId
    var room = rooms[roomId]
    var buyOrSellStockPrice =
      gamePrices[roomId][
        gamePrices[roomId].findIndex(stock => stock.name === data.stock)
      ]['price'] * data.amount
    if (data.action === 'Buy') {
      if (user.money >= buyOrSellStockPrice && user.chancesPlayed < 3) {
        room['players'].forEach(player => {
          if (player.id === client.id) {
            buyStock = data.stock
            buyAmount = data.amount
            stockActions[roomId]['Buy'][buyStock] = buyAmount
            io.to(roomId).emit('dashboardChanges', {
              stockActions: stockActions[roomId]
            })
            player.money -= buyOrSellStockPrice
            player['boughtStocks'][data.stock]
              ? (player['boughtStocks'][data.stock] += data.amount)
              : (player['boughtStocks'][data.stock] = data.amount)
            player['chancesPlayed']++
            user['money'] -= buyOrSellStockPrice
            user['boughtStocks'][data.stock]
              ? (user['boughtStocks'][data.stock] += data.amount)
              : (user['boughtStocks'][data.stock] = data.amount)
            user['chancesPlayed']++
          }
        })
        io.to(roomId).emit('playerListChange', {
          players: room['players']
        })
        console.log(buyOrSellStockPrice)
        io.to(roomId).emit('actionResponse', {
          action: `${user.username} bought ${data.amount} ${data.stock} stocks for ₹${buyOrSellStockPrice}`
        })
      } else {
        if (user.chancesPlayed >= 3) {
          io.to(client.id).emit('buyOrSellStockError', 'Not enough chances')
        }
        if (user.money < buyOrSellStockPrice) {
          io.to(client.id).emit('buyOrSellStockError', 'Not enough money')
        }
      }
    }
    if (data.action === 'Sell') {
      if (
        user.boughtStocks[data.stock] >= data.amount &&
        user.chancesPlayed < 3
      ) {
        room['players'].forEach(player => {
          if (player.id === client.id) {
            sellStock = data.stock
            sellAmount = data.amount
            stockActions[roomId]['Sell'] = { sellStock: sellAmount }
            io.to(roomId).emit('dashboardChanges', {
              stockActions: stockActions
            })
            player['boughtStocks'][data.stock] -= data.amount
            player.money += buyOrSellStockPrice
            player['chancesPlayed']++
            user['money'] += buyOrSellStockPrice
            user['boughtStocks'][data.stock] -= data.amount
            user['chancesPlayed']++
          }
        })
        io.to(roomId).emit('playerListChange', {
          players: room['players']
        })
        io.to(roomId).emit('actionResponse', {
          action: `${user.username} sold ${data.amount} ${data.stock} stocks for ₹${buyOrSellStockPrice}`
        })
      } else {
        if (user.chancesPlayed >= 3) {
          io.to(client.id).emit('buyOrSellStockError', 'Not enough chances')
        }
        if (
          user.boughtStocks[data.stock] < data.amount ||
          user.boughtStocks[data.stock] === undefined
        ) {
          io.to(client.id).emit(
            'buyOrSellStockError',
            'Not enough stocks to sell'
          )
        }
      }
    }
    checkGameOver(roomId)
  })
  client.on('claimLoanStockMature', function () {
    var user = users[client.id]
    var roomId = user.roomId
    var room = rooms[roomId]
    room['players'].forEach(player => {
      if (
        player.id === client.id &&
        player.chancesPlayed < 3 &&
        player.cards.filter(card => card.shareName === 'Loan Stock Mature')
          .length > 0
      ) {
        player.money += 100000
        user.money += 100000
        player.chancesPlayed++
        user.chancesPlayed++
        player['cards'].splice(
          player['cards'].indexOf(
            player['cards'].filter(
              card => card.shareName === 'Loan Stock Mature'
            )[0]
          ),
          1
        )
        io.to(roomId).emit('playerListChange', {
          players: room['players']
        })
        io.to(roomId).emit('actionResponse', {
          action: `${user.username} claimed loan stock mature of ₹100000`
        })
      } else {
        if (player.id === client.id) {
          if (player.chancesPlayed >= 3) {
            io.to(client.id).emit('actionResponseError', {
              action: 'You do not have any chances left'
            })
          }
          if (
            !player.cards.filter(card => card.shareName === 'Loan Stock Mature')
              .length > 0
          ) {
            io.to(client.id).emit('actionResponseError', {
              action: 'You do not have the loan stock mature card'
            })
          }
        }
      }
    })
    checkGameOver(roomId)
  })
  client.on('endGame', function () {
    changeStockPrices(users[client.id].roomId)
    calculateScores(client.id)
  })
  client.on('winnerList', function (data) {
    var roomId = users[client.id].roomId
    var players = rooms[roomId]['players']
    var sortedScores = players.sort((a, b) => b.totalScore - a.totalScore)
    console.log(sortedScores)
    io.to(client.id).emit('winnerListResponse', {
      winnerList: sortedScores
    })
  })
  client.on('endRoundByHost', function (data) {
    var roomId = users[client.id].roomId
    checkGameOver(roomId, true)
  })
})

const distributeCards = roomId => {
  var players = rooms[roomId]['players']
  var numberOfCards = 10
  // console.log(typeof cards['cards'])
  // console.log(cards['cards'])
  players.forEach(player => {
    var shuffled = cards['cards'].sort(_ => 0.5 - Math.random())
    var playerCards = shuffled.slice(0, numberOfCards)
    player['cards'] = playerCards
    player['chancesPlayed'] = 0
    var playerSocketId = player['id']
    users[playerSocketId]['cards'] = playerCards
    users[playerSocketId]['chancesPlayed'] = 0
    io.to(player.id).emit('yourCards', {
      cards: playerCards,
      chancesPlayed: users[playerSocketId]['chancesPlayed']
    })
  })
}

const changeStockPrices = (roomId, sendPrices = false) => {
  var stockPrices = gamePrices[roomId]
  var playerCards = []
  rooms[roomId]['players'].map(player => {
    playerCards = playerCards.concat(player['cards'].map(card => card))
  })
  playerCards.forEach(playerCard => {
    console.log(playerCard)
  })
  stockPrices.forEach(stock => {
    var allChanges = playerCards.filter(card => stock.name === card.shareName)
    if (!stock.shareName == 'Currency') {
      console.log(allChanges)
      var totalChange = 0
      allChanges.forEach(change => {
        console.log(change.change)
        totalChange += parseInt(change.change)
      })
      console.log(stock.name, stock.price, totalChange)
      stock['price'] =
        parseInt(stock['price']) + parseInt(totalChange) > 0
          ? parseInt(stock['price']) + parseInt(totalChange)
          : 0
    } else {
      var totalChange = 0
      allChanges.forEach(change => {
        console.log(change.change)
        totalChange += parseInt(change.change)
      }
      )
      rooms[roomId]['players'].forEach(player => {
        player['money'] += Math.round((totalChange/100)*player['money'])
        io.to(player.id).emit("currencyChange", {
          perChange: totalChange,
          money: player['money'],
          change: Math.round((totalChange/100)*player['money'])
        })
      })
      io.to(roomId).emit('playerListChange', {
        players: rooms[roomId]['players']
      })
    }
  })
  if (sendPrices) {
    io.to(roomId).emit('stockPricesChange', {
      prices: stockPrices
    })
  }
  distributeCards(roomId)
}

const checkGameOver = (roomId, force = false) => {
  var allChancesPlayed = []
  if (!force) {
    var allChancesPlayed = rooms[roomId]['players'].filter(
      player => player.chancesPlayed === 3
    )
  }
  if (allChancesPlayed.length === rooms[roomId]['players'].length || force) {
    rooms[roomId]['totalRounds']++
    rooms[roomId]['roundOver'] = true
    stockActions[roomId] = { Buy: {}, Sell: {} }
    io.to(roomId).emit('roundOver', force ? 'The host ended the round' : null)
  }
}

const calculateScores = id => {
  var user = users[id]
  var room = rooms[user.roomId]
  var players = room['players']
  players.forEach(player => {
    var playerScore = player.money
    if (player.boughtStocks == {}) {
      playerScore = player.money
    }
    console.log(player.boughtStocks)
    for (var stock in player.boughtStocks) {
      console.log(stock, player.boughtStocks[stock])
      stockPrice = gamePrices[user.roomId].filter(
        stockPrice => stockPrice.name === stock
      )[0].price
      playerScore += player.boughtStocks[stock] * stockPrice
    }
    player['totalScore'] = playerScore
    console.log(player.username, player.totalScore)
    io.to(player.id).emit('yourScore', {
      yourScore: playerScore
    })
  })
}

var port = process.env.PORT || 3000
httpServer.listen(port, function (err) {
  if (err) console.log(err)
  console.log('Listening on port', port)
})
