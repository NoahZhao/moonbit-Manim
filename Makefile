.PHONY: check test demo demo-foundation demo-create demo-videos tex-assets lesson-stills lesson-videos dynamics-stills dynamics-videos

check:
	moon fmt --check
	moon check --target all --deny-warn

test:
	moon test --target all --deny-warn
	moon test --target native --release --deny-warn

demo: demo-foundation demo-create

demo-foundation:
	mkdir -p output
	moon run src/cmd/demo --target native --deny-warn > output/foundation.svg

demo-create:
	mkdir -p output
	moon run src/cmd/create --target native --deny-warn > output/create.svg

demo-videos:
	node scripts/render-videos.cjs

tex-assets:
	node scripts/compile-tex.cjs

lesson-stills:
	node scripts/render-videos.cjs --lessons --stills

lesson-videos:
	node scripts/render-videos.cjs --lessons

dynamics-stills:
	node scripts/render-videos.cjs --dynamics --stills

dynamics-videos:
	node scripts/render-videos.cjs --dynamics
