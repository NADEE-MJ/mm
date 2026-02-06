/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        primary: {
          DEFAULT: '#DBA506',
          dark: '#B88A05',
          light: '#F2DB83',
        },
      },
    },
  },
  plugins: [],
}
