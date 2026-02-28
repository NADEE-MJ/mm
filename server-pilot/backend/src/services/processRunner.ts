export type CommandRunOptions = {
  cwd?: string;
  env?: Record<string, string>;
  timeoutMs?: number;
  allowNonZero?: boolean;
};

export type CommandResult = {
  exitCode: number;
  stdout: string;
  stderr: string;
  durationMs: number;
};

const readStream = async (stream: ReadableStream<Uint8Array> | null): Promise<string> => {
  if (!stream) {
    return "";
  }

  return new Response(stream).text();
};

export const runCommand = async (
  cmd: string[],
  options: CommandRunOptions = {},
): Promise<CommandResult> => {
  if (cmd.length === 0) {
    throw new Error("Command must include at least one argument");
  }

  const startedAt = Date.now();
  const timeoutMs = options.timeoutMs ?? 15000;

  const process = Bun.spawn({
    cmd,
    cwd: options.cwd,
    env: options.env,
    stdout: "pipe",
    stderr: "pipe",
  });

  let timedOut = false;
  const timeout = setTimeout(() => {
    timedOut = true;
    process.kill();
  }, timeoutMs);

  const [exitCode, stdout, stderr] = await Promise.all([
    process.exited,
    readStream(process.stdout),
    readStream(process.stderr),
  ]);

  clearTimeout(timeout);

  if (timedOut) {
    throw new Error(`Command timed out after ${timeoutMs}ms: ${cmd.join(" ")}`);
  }

  const result: CommandResult = {
    exitCode,
    stdout: stdout.trim(),
    stderr: stderr.trim(),
    durationMs: Date.now() - startedAt,
  };

  if (!options.allowNonZero && exitCode !== 0) {
    throw new Error(
      `Command failed (${exitCode}): ${cmd.join(" ")}${
        result.stderr ? `\n${result.stderr}` : ""
      }`,
    );
  }

  return result;
};
