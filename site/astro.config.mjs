// @ts-check
import { defineConfig } from "astro/config";
import starlight from "@astrojs/starlight";

// Starlight docs live under /docs/* via nested src/content/docs/docs/ (manual setup).
// Landing page: src/pages/index.astro
export default defineConfig({
  site: "https://szTheory.github.io",
  base: "/kiln",
  integrations: [
    starlight({
      title: "Kiln",
      customCss: ["./src/styles/custom.css"],
      sidebar: [
        { label: "Overview", link: "/docs/" },
        { label: "Onboarding", link: "/onboarding/" },
        { label: "Workflows", link: "/workflows/" },
        { label: "Architecture", link: "/architecture/" },
        { label: "Configuration", link: "/configuration/" },
      ],
    }),
  ],
});
