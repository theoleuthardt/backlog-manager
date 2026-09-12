function parseSseMessage(raw: string): { event: string | null; data: string } {
  let event: string | null = null;
  const dataLines: string[] = [];
  for (const line of raw.split(/\r\n|\n/)) {
    if (line.startsWith("event: ")) {
      event = line.slice("event: ".length);
    } else if (line.startsWith("data: ")) {
      dataLines.push(line.slice("data: ".length));
    }
  }
  return { event, data: dataLines.join("\n") };
}

/**
 * Reads a backend SSE response and dispatches each `event: .../data: ...`
 * message it decodes. Resolves with the payload of the terminal `done`
 * message, or rejects with the payload of a terminal `error` message.
 * Callers pass the response from a fully typed `apiClient.POST(path,
 * { parseAs: "stream" })` call, so the bearer-token middleware and 401
 * token-clearing stay in effect for streams too.
 *
 * Each raw chunk read from the stream is accumulated un-normalized into
 * `buffer` - a chunk boundary can land mid-separator (e.g. "...\r\n\r"
 * then "\n..."), so normalizing each chunk before concatenating (rather
 * than searching the combined buffer) would fail to recognize the
 * reassembled separator.
 */
export async function streamSse<TProgress, TResult>(
  response: Response,
  handlers: {
    onProgress: (progress: TProgress) => void;
  },
): Promise<TResult> {
  if (!response.ok || !response.body) {
    throw new Error(`SSE request failed with status ${response.status}`);
  }

  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let buffer = "";
  let result: TResult | undefined;
  let streamError: string | undefined;

  const boundaryPattern = /\r\n\r\n|\n\n/;

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    buffer += decoder.decode(value, { stream: true });

    let match = boundaryPattern.exec(buffer);
    while (match !== null) {
      const raw = buffer.slice(0, match.index);
      buffer = buffer.slice(match.index + match[0].length);
      if (raw) {
        const { event, data } = parseSseMessage(raw);
        if (event === "progress") {
          handlers.onProgress(JSON.parse(data) as TProgress);
        } else if (event === "done") {
          result = JSON.parse(data) as TResult;
        } else if (event === "error") {
          streamError = data;
        }
      }
      match = boundaryPattern.exec(buffer);
    }
  }

  if (streamError) throw new Error(streamError);
  if (result === undefined) {
    throw new Error("SSE stream ended without a result");
  }
  return result;
}