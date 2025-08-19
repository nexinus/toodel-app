// tailwind.config.js
module.exports = {
    content: [
      "./app/views/**/*.html.erb",
      "./app/helpers/**/*.rb",
      "./app/javascript/**/*.js",
      "./app/assets/stylesheets/**/*.css"
    ],
    theme: {
      extend: {
        colors: {
          neon: {
            pink: '#FF5CAD',
            purple: '#7C3AED',
            cyan: '#00E5FF',
            teal: '#00D4B8'
          },
          glass: 'rgba(255,255,255,0.06)'
        },
        fontFamily: {
          sans: ['Inter', 'ui-sans-serif', 'system-ui'],
          display: ['Poppins', 'Inter']
        }
      }
    },
    plugins: []
  }
  