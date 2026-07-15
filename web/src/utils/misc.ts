// Will return whether the current environment is in a regular browser
// and not CEF
export const isEnvBrowser = (): boolean => !(window as any).invokeNative;

// Basic no operation function
export const noop = () => {};

export function getResourceName(): string {
  return (window as any).GetParentResourceName?.() ?? "nn_postman";
}

/** Build a URL FiveM CEF can load for files listed in fxmanifest `files`. */
export function getNuiAssetUrl(relativePath: string): string {
  const cleanPath = relativePath.replace(/^\/+/, "");
  if (isEnvBrowser()) {
    return `/${cleanPath}`;
  }
  return `https://cfx-nui-${getResourceName()}/${cleanPath}`;
}
