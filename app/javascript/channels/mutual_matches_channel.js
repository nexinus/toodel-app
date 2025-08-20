import consumer from "./consumer"

consumer.subscriptions.create("MutualMatchesChannel", {
  connected() {},
  disconnected() {},
  received(data) {
    // basic notification — replace with nicer UI later
    console.log("MutualMatchesChannel received:", data)
    if (data.message) {
      // For now, log; your front-end can render toast later
      alert(data.message)
    }
  }
})
