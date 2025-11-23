/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  darkMode: 'class', // Enable class-based dark mode
  theme: {
    extend: {
      colors: {
        // Custom color palette for dark mode
        'dark-bg': '#0f172a',        // slate-900
        'dark-surface': '#1e293b',   // slate-800
        'dark-border': '#334155',    // slate-700
        'dark-text': '#e2e8f0',      // slate-200
        'dark-text-muted': '#94a3b8', // slate-400
        'primary': '#3b82f6',        // blue-500
        'primary-hover': '#2563eb',  // blue-600
      },
    },
  },
  plugins: [],
}
