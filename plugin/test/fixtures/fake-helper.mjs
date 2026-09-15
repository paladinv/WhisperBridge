#!/usr/bin/env node

let request = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", chunk => { request += chunk; });
process.stdin.on("end", () => {
  const parsed = JSON.parse(request);
  if (parsed.version !== 1) process.exit(2);
  process.stdout.write(JSON.stringify({ type: "stage", stage: "transcribing" }) + "\n");
  process.stdout.write(JSON.stringify({
    type: "result",
    text: "Fixture transcript",
    detectedLanguage: "English"
  }) + "\n");
});
