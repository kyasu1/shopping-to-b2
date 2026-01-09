// Import styles
import '../static/input.css'

// Import Elm app
import { Elm } from './Main.elm'

// Initialize Elm application
const app = Elm.Main.init({
  node: document.getElementById('elm-app')
})

// Handle CSV download port
app.ports.downloadCsv.subscribe(function(data) {
  fetch('/save', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data)
  })
  .then(response => {
    if (!response.ok) {
      throw new Error('サーバーエラー')
    }

    // Extract filename from Content-Disposition header or use default
    const contentDisposition = response.headers.get('Content-Disposition')
    let filename = 'yamato_output.csv'
    if (contentDisposition) {
      const match = contentDisposition.match(/filename="?(.+)"?/)
      if (match && match.length > 1) {
        filename = match[1]
      }
    }

    return response.blob().then(blob => ({ blob, filename }))
  })
  .then(({ blob, filename }) => {
    const url = window.URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = filename
    document.body.appendChild(a)
    a.click()
    document.body.removeChild(a)
    window.URL.revokeObjectURL(url)
  })
  .catch(error => {
    console.error('保存エラー:', error)
    alert('保存エラー: ' + error.message)
  })
})
