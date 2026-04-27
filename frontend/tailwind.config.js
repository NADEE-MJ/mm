export default {
  content: ["./index.html", "./src/**/*.{js,ts,jsx,tsx}"],
  darkMode: "class",
  theme: {
    extend: {
      colors: {
        primary: {
          DEFAULT: "#0a84ff",
          dark: "#0867c6",
          light: "#65b3ff"
        }
      }
    }
  },
  plugins: []
};
