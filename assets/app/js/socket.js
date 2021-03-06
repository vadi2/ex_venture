import {Socket} from "phoenix"
import Sizzle from "sizzle"
import _ from "underscore"

import CommandHistory from "./command-history"
import {appendMessage, scrollToBottom} from "./panel"
import {gmcpMessage} from "./gmcp"
import {guid} from "./utils"
import Logger from "./logger"

class ChannelWrapper {
  constructor(channel) {
    this.channel = channel
  }

  send(message) {
    this.channel.push("recv", {message: message})
  }
}

var body = document.getElementById("body")
var userToken = body.getAttribute("data-user-token")

let socket = new Socket("/socket", {params: {token: userToken}})
socket.connect()

let options = {
  echo: true,
};

// Now that you are connected, you can join channels with a topic:
let channel = socket.channel("telnet:" + guid(), {})
let channelWrapper = new ChannelWrapper(channel)

channel.onMessage = function (event, payload, ref) {
  if (payload != undefined && payload.sent_at) {
    let sentAt = Date.parse(payload.sent_at)
    let receivedAt = new Date().getTime()
    let totalTimeMs = receivedAt - sentAt
    Logger.log(event, `${totalTimeMs}ms`)
  }
  return payload
}

channel.on("option", payload => {
  let commandPrompt = document.getElementById("prompt")

  switch (payload.type) {
    case "echo":
      options.echo = payload.echo

      if (payload.echo) {
        commandPrompt.type = "text"
      } else {
        commandPrompt.type = "password"
      }

      break;
    default:
      console.log("No option found")
  }
})

channel.on("gmcp", gmcpMessage(channelWrapper))
channel.on("prompt", appendMessage)
channel.on("echo", appendMessage)
channel.on("disconnect", payload => {
  document.getElementById("terminal").append("\nDisconnected.")
  socket.disconnect()
  scrollToBottom()
})

let commandHistory = new CommandHistory()

document.getElementById("prompt").addEventListener("keydown", e => {
  let commandPrompt = document.getElementById("prompt")

  switch (e.keyCode) {
    case 38:
      commandHistory.scrollBack((command) => {
        commandPrompt.value = command
      })
      break;
    case 40:
      commandHistory.scrollForward((command) => {
        commandPrompt.value = command
      })
      break;
  }
})

let sendCommand = command => {
  if (options.echo) {
    commandHistory.add(command);
    appendMessage({message: command + "<br />", delink: true});
  }

  document.getElementById("prompt").value = "";
  channelWrapper.send(command);
}

document.getElementById("prompt").addEventListener("keypress", e => {
  if (e.keyCode == 13) {
    var command = document.getElementById("prompt").value
    sendCommand(command);
  }
})

document.addEventListener("click", e => {
  if (e.target.classList.contains("command")){
    if (e.target.dataset.command != undefined) {
      sendCommand(e.target.dataset.command);
    } else {
      sendCommand(e.target.innerText);
    }
  }
}, false);

document.addEventListener("mouseover", e => {
  if (e.target.classList.contains("command")) {
    if (e.target.dataset.command != undefined) {
      e.target.setAttribute("data-title", e.target.dataset.command);
    } else {
      e.target.setAttribute("data-title", e.target.innerText);
    }
  }
}, false);

export {channel}
