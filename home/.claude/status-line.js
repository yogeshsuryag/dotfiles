let input = "";

process.stdin.setEncoding("utf8");
process.stdin.on("data", (chunk) => {
  input += chunk;
});

process.stdin.on("end", () => {
  let data = {};
  try {
    data = JSON.parse(input);
  } catch {
    process.stdout.write("Claude");
    return;
  }

  const model = data?.model?.display_name || "Claude";
  const used = data?.context_window?.used_percentage;
  if (typeof used === "number") {
    process.stdout.write(`${model} | ctx: ${Math.round(used)}% used`);
  } else {
    process.stdout.write(model);
  }
});
