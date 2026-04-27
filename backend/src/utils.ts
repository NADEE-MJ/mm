import path from "node:path";

/**
 * Resolves a path that may be relative (e.g. "./data/db") to an absolute path
 * anchored at `process.cwd()`. Absolute paths are returned unchanged.
 */
export const resolveProjectRelativePath = (rawPath: string): string => {
  if (path.isAbsolute(rawPath)) {
    return rawPath;
  }
  return path.resolve(process.cwd(), rawPath.replace(/^\.\//, ""));
};
