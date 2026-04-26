// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/kiln"
import topbar from "../vendor/topbar"

const OPERATOR_MODE_KEY = "kiln:operator-mode"
const DEMO_SCENARIO_KEY = "kiln:demo-scenario"

const readOperatorMode = () => {
  try {
    const stored = window.localStorage.getItem(OPERATOR_MODE_KEY)
    return stored === "demo" || stored === "live" ? stored : null
  } catch {
    return null
  }
}

const writeOperatorMode = (mode) => {
  if (mode !== "demo" && mode !== "live") return

  try {
    window.localStorage.setItem(OPERATOR_MODE_KEY, mode)
  } catch {
    // Ignore localStorage failures; the server event still updates the page.
  }
}

const readDemoScenario = () => {
  try {
    const stored = window.localStorage.getItem(DEMO_SCENARIO_KEY)
    return stored && stored.length > 0 ? stored : null
  } catch {
    return null
  }
}

const writeDemoScenario = (scenarioId) => {
  if (!scenarioId || scenarioId.length === 0) return

  try {
    window.localStorage.setItem(DEMO_SCENARIO_KEY, scenarioId)
  } catch {
    // Ignore localStorage failures; the server event still updates the page.
  }
}

const OperatorModeControl = {
  mounted() {
    this.select = this.el.querySelector("#operator-mode-select")

    this.onChange = (event) => {
      const value = event.target.value
      if (value === "demo" || value === "live") writeOperatorMode(value)
    }

    this.el.addEventListener("change", this.onChange)

    const current = this.el.dataset.currentMode
    const stored = readOperatorMode()

    if (this.select && stored && this.select.value !== stored) {
      this.select.value = stored
    }

    if (stored && stored !== current) {
      this.pushEvent("operator:set_mode", {mode: stored})
    } else if (!stored && (current === "demo" || current === "live")) {
      writeOperatorMode(current)
    }
  },

  destroyed() {
    this.el.removeEventListener("change", this.onChange)
  },
}

const OperatorScenarioControl = {
  mounted() {
    this.select = this.el.querySelector("#operator-scenario-select")
    if (!this.select) return

    this.available = new Set(
      Array.from(this.select.options)
        .map((option) => option.value)
        .filter((value) => value.length > 0)
    )

    this.onChange = (event) => {
      const value = event.target.value
      if (this.available.has(value)) writeDemoScenario(value)
    }

    this.el.addEventListener("change", this.onChange)

    const current = this.el.dataset.currentScenario
    const stored = readDemoScenario()

    if (current && this.available.has(current)) {
      if (this.select.value !== current) this.select.value = current
      if (stored !== current) writeDemoScenario(current)
      return
    }

    if (stored && this.available.has(stored)) {
      if (this.select.value !== stored) this.select.value = stored
      this.pushEvent("operator:set_scenario", {id: stored})
    }
  },

  destroyed() {
    this.el.removeEventListener("change", this.onChange)
  },
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: () => {
    const operatorMode = readOperatorMode()
    const operatorScenario = readDemoScenario()

    return {
      _csrf_token: csrfToken,
      ...(operatorMode ? {operator_runtime_mode: operatorMode} : {}),
      ...(operatorScenario ? {operator_demo_scenario: operatorScenario} : {}),
    }
  },
  hooks: {...colocatedHooks, OperatorModeControl, OperatorScenarioControl},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", _e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}
