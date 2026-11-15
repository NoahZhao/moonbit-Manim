# Formula asset provenance

teaching.json and src/teaching/assets.generated.mbt are generated from
fragments.json by scripts/compile-tex.cjs using MathJax 3.2.2's TeX SVG font
definitions and layout. Quadratic paths are elevated to cubics and SVG
transforms are baked into coordinates. These are transformed vector assets,
not a new font design.

MathJax is Copyright (c) 2009-2022 The MathJax Consortium and is distributed
under the Apache License, Version 2.0. A copy is included in
MATHJAX-LICENSE.txt. MathJax source: https://github.com/mathjax/MathJax-src.

The MathJax SVG font data headers attribute the relevant code to The MathJax
Consortium. The dependency package's license is the source of the license
copy; consult its distribution for the complete upstream notices.
