#!/usr/bin/env node

let request = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", chunk => { request += chunk; });
process.stdin.on("end", () => {
  const parsed = JSON.parse(request);
  if (parsed.version !== 3 || !parsed.modelID || !parsed.engine || !parsed.modelDirectory) process.exit(2);
  process.stdout.write(JSON.stringify({ type: "stage", stage: "transcribing" }) + "\n");
  const result = {
    type: "result",
    text: "Fixture transcript",
    detectedLanguage: "English"
  };
  if (parsed.engine === "moss") {
    result.segments = [{ start: 0.1, end: 1.2, speaker: "S01", text: "Fixture transcript" }];
  }
  process.stdout.write(JSON.stringify(result) + "\n");
});
