## 2026-10-23 - Active Polling vs Fixed Timeouts
**Learning:** Fixed `setTimeout` in headless browser scripts wastes 2-3 seconds per run when pages load fast, acting as a massive bottleneck for automation tasks.
**Action:** Always replace fixed `setTimeout` delays with active polling (`setInterval` or recursive `setTimeout` checking for a condition) for elements when driving browser CDP.
