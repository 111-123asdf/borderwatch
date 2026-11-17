# pixelfx · retained offline authoring source

Upstream: https://github.com/patch-gg/pixelfx (MIT; LICENSE and NOTICE.md retained).
This project retains source and offline tools for tools/compile_pixelfx.mjs, which produces the current assets/v016/fx_*.png sheets. Gallery assets and readme demonstration GIFs are archived outside the source project during the v0.19 closeout; this is not a full upstream checkout. Upstream gallery instructions do not apply to this trimmed copy.

Run the project compiler from the canonical project: node tools/compile_pixelfx.mjs (Node >=18). Optional developer dependencies belong in a local environment and are not shipped as node_modules. Compiling regenerates production art: do it intentionally and review the output, not during routine verification.
