'use strict';

const express = require('express');
const shell = require("shelljs");
const fs = require('fs');

// Constants
const PORT = 8080;
const HOST = '0.0.0.0';

var log_file = "/var/log/openvpn"

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

app.get('/log', (req, res) => {
  var log = ""
  if (fs.existsSync(log_file))
    log = fs.readFileSync(log_file, "utf8")
  var html = `<pre>${log}</pre>`
  res.send(html)
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