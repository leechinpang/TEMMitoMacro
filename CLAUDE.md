# CLAUDE.md — TEMMitoMacro

## What this project is
Two Fiji/ImageJ macros (`.ijm`) for semi-automated measurement of mitochondrial
morphology in transmission electron microscopy (TEM) images.

**Current goal:** use Fiji to read and analyse TEM images of pancreatic **beta cells**
(e.g. mitochondrial changes across experimental conditions), with results that hold
up in a paper: traceable to image/cell/animal, in calibrated units, and validated
against manual tracing.

## Files
| File | Role |
|---|---|
| `ROIBatchGen-windows.ijm` | Interactive. Opens each image in a folder; user draws ROIs (press `t` to add each to ROI Manager); saves `ROIs/ROIs-<image>.zip`. |
| `EM-MitoMorphMacr-windows.ijm` | Batch. Preprocesses each image, thresholds to a binary mask, loads the matching ROI zip, runs Analyze Particles per ROI, saves count masks and `<condition>-Results.csv`, then computes summary metrics (form factor, area-weighted FF, aspect ratio). |
| `README.md` | Short description; metrics follow Merrill, Flippo & Strack 2017. |

Pipeline: images in one folder per condition → run ROIBatchGen → run EM-MitoMorph on
the same folder → per-particle CSV + summary printed to the Log window.

## How to run
- Fiji → Plugins ▸ Macros ▸ Run… → pick the `.ijm` file. Both macros prompt for the
  input folder, file suffix (default `.tif`) and a condition label.
- There is no headless entry point yet (macros use `getDirectory`/`Dialog`).
  Prefer converting inputs to script parameters (`#@ File (style="directory") input`,
  `#@ String condition`, …) so the batch macro can run headless:
  `ImageJ-<platform> --headless --console -macro EM-MitoMorphMacr-windows.ijm "input=…,condition=…"`.

## Language and coding conventions (ImageJ macro language)
- Build paths with `File.separator`; `getDirectory()` already returns a trailing
  separator, so don't add another.
- Track images by `getImageID()` / `selectImage(id)`, not by auto-generated window
  titles like `"Mask-"+m`.
- Initialise every accumulator before use; end statements with `;`.
- Call `run("Clear Results")` and reset the ROI Manager at the start of a run.
- Don't change global Fiji settings (e.g. `setOption("BlackBackground", …)`) without
  restoring the user's original value at the end.
- Use `setBatchMode(true)` in the non-interactive macro.
- Keep the two macros consistent: same folder layout, same recursion behaviour,
  same naming of ROI zips.

## Domain rules (don't break these)
- **Units:** check `getPixelSize(unit, pw, ph)` on every image. Size filters in
  `Analyze Particles` are in calibrated units unless `pixel` is given. Never mix
  images of different magnifications under pixel-based parameters
  (rolling ball 60, bandpass 8–60, size ≥600, subtract 100 all assume one
  magnification and bit depth).
- **Traceability:** every row in the results must carry image name, ROI index
  (= cell), and condition. Enable `display` (label) in Set Measurements and add
  explicit columns.
- **Unit of analysis:** mitochondria are nested in cells, cells in islets/animals.
  Don't report pooled per-mitochondrion means as the final statistic; export
  per-particle data and aggregate per cell/animal downstream (R).
- **Beta-cell specifics:** insulin secretory granules (dense core + halo), ER and
  lipid droplets can pass the threshold and size filter. Any change to
  preprocessing/threshold/morphology must be validated against manual tracing on a
  held-out set, ideally by an observer blinded to condition.
- Morphology ops (dilate/fill/close/erode/open) alter perimeter and therefore form
  factor; document any change and its validation result.
- Metric definitions: FF = P²/(4πA); area-weighted FF = Σ(P²/4π)/ΣA;
  AR = major/minor. Divide by totals, not by means.

## Known issues (from code review, Nov 2026) — fix before trusting outputs
1. `ar_sum`, `ff_sum`, `sum_a_sq` used without initialisation (summary block).
2. `awff` is divided by mean area instead of total area → inflated by n.
3. "Area2" = Σa² / (mean a)² → scales with particle count.
4. `size=600-Infinity` is not in pixels if the image is calibrated.
5. Results table has no image/ROI label; not cleared at start; summary only in Log.
6. Zero ROIs for an image → `roiManager("delete")`/missing zip aborts the run.
7. ROIBatchGen recurses into subfolders; EM-MitoMorph doesn't → subfolder images
   get ROIs but are never analysed.
8. `setOption("BlackBackground", false)` changes the user's global setting.
9. `exclude` drops particles touching the ROI border → bias if ROIs are drawn tightly.

## Testing
No tests exist. Add:
- `tests/fixtures/`: synthetic 8-bit image(s) with ellipses of known area/perimeter
  at a known calibration, plus a matching ROI zip.
- `tests/expected/`: expected CSV (area, perimeter, FF, AR within tolerance).
- A headless runner script that runs the batch macro on fixtures and diffs output.
- A small manually-traced validation set of real beta-cell TEM images
  (segmentation agreement, e.g. Dice/IoU; metric agreement, e.g. Bland–Altman).

## Data handling
- Don't commit raw TEM images, animal/patient identifiers, or result CSVs from real
  experiments. Keep only small synthetic fixtures in the repo.

## Working with Claude
- Make small, reviewable changes; explain any change to image-processing
  parameters and its expected effect on measurements.
- When unsure whether a change affects published numbers, flag it rather than
  silently changing behaviour.
