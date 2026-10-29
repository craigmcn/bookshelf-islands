// Entry point for the build script in your package.json
import "@hotwired/turbo-rails"
import "./controllers"
import * as bootstrap from "bootstrap"
// ported from community_bookshelf app/javascript/application.js — chartkick
// scans the DOM for the chart divs its own Rails helpers (pie_chart etc.)
// render and draws them with Chart.js; no Stimulus/React involved.
import Chartkick from "chartkick"
import "chartkick/chart.js"

window.Chartkick = Chartkick
