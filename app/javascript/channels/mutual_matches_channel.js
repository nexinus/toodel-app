// import consumer from "channels/consumer"
import consumer from "./consumer"

consumer.subscriptions.create("MutualMatchesChannel", {
  connected() {
    // Called when the subscription is ready for use on the server
    console.log("Connected to MutualMatchesChannel")
  },

  disconnected() {
    // Called when the subscription has been terminated by the server
    console.log("Disconnected from MutualMatchesChannel")
  },

  received(data) {
    // data => { target: "Alice", target_id: 5 }
    // const message = `🎉 You and ${data.target} matched!`
    // Display a simple alert or inject into your UI
    //alert(message)
    // Or prepend to a notification list:
    // const container = document.getElementById("notifications")
    // container.insertAdjacentHTML("afterbegin", `<div>${message}</div>`)
    // Replace with better UI later (toast), for now simple alert
    alert(data.message || `You matched with ${data.target || data.name}`)
  }
});
