'use strict';

const express = require('express');
const shell = require("shelljs")

// Constants
const PORT = 8080;
const HOST = '0.0.0.0';

// App
const app = express();
app.set('views', 'src/')
app.set('view engine', 'pug')

var state = false

app.get('/', (req, res) => {
  res.render('index')
});

app.get('/button', (req, res) => {
  res.render('button', {
    status: (state?"off":"on")
  })
})

app.get('/toggle', (req, res) => {
  var new_state;
  switch(req.query.next) {
    case "on": new_state=true; break;
    case "off": new_state=false; break;
    default: res.json({status: "error"}); return 
  }
  state = new_state

  // start openvpn (check is done in file) 
  if (new_state)
    shell.exec("/control-script/run.sh")
  else 
    shell.exec("/control-script/stop.sh")

  res.json({status: "ok", new: req.query.next })
})

app.listen(PORT, HOST);
console.log(`Running on http://${HOST}:${PORT}`);