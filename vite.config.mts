import { defineConfig } from "vite";
import tailwindcss from "@tailwindcss/vite";
import RubyPlugin from "vite-plugin-ruby";
import fullReload from "vite-plugin-full-reload";

export default defineConfig(() => ({
  plugins: [
    tailwindcss(),
    RubyPlugin(),
    // Improve DX in dev without affecting production builds.
    fullReload(["config/routes.rb", "app/views/**/*"], { delay: 300 }),
  ],
  build: {
    sourcemap: false,
  },
  optimizeDeps: {
    include: ["@hotwired/turbo-rails", "@rails/activestorage"],
  },
}));