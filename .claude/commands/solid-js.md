# SolidJS Development Assistant

You are helping with SolidJS development inside a NixOS/home-manager configuration repository.

## Repository Context

This repository manages NixOS configurations. The flake uses `nixpkgs-unstable` on `x86_64-linux`. The devShell already includes `biome` for JS/TS formatting. Direnv is configured, so `.envrc` files with `use flake` work automatically.

---

## 1. Packaging a SolidJS App in Nix

Use `pkgs.buildNpmPackage` for projects with a `package-lock.json`. Vite outputs to `dist/` by default.

```nix
{ pkgs, ... }:

pkgs.buildNpmPackage {
  pname = "my-solid-app";
  version = "0.1.0";
  src = ./.;
  npmDepsHash = pkgs.lib.fakeHash; # replace with real hash after first `nix build`

  installPhase = ''
    runHook preInstall
    cp -r dist $out
    runHook postInstall
  '';
}
```

Run `nix build` once — it will fail and print the correct hash. Replace `fakeHash` with it.

Expose it as a flake output in `flake.nix`:

```nix
packages.${system}.my-solid-app = pkgs.callPackage ./packages/my-solid-app {};
```

---

## 2. devShell Setup

Add a dedicated shell in `flake.nix` for the SolidJS project:

```nix
devShells.${system}.solid-app = pkgs.mkShell {
  buildInputs = with pkgs; [
    biome
    nodejs_22
    nodePackages.npm
  ];
  shellHook = ''
    export NODE_ENV=development
  '';
};
```

Reference from the project directory with `.envrc`:

```sh
use flake .#solid-app
```

`vite.config.ts` for SolidJS:

```ts
import { defineConfig } from "vite";
import solid from "vite-plugin-solid";

export default defineConfig({
  plugins: [solid()],
  build: { outDir: "dist" },
});
```

---

## 3. SolidJS Component Patterns

### Signals

Always call signals as functions. Never destructure props.

```tsx
import { createSignal, createMemo } from "solid-js";

function Counter() {
  const [count, setCount] = createSignal(0);
  const doubled = createMemo(() => count() * 2);
  return <button onClick={() => setCount(count() + 1)}>{count()} ({doubled()})</button>;
}
```

### Deriving values from props

Prefer `createStore` with getter functions over `createMemo`. Getters inside a store are memoised and track reactive dependencies:

```tsx
import { createStore } from "solid-js/store";

function Component(props: { value: number }) {
  const [store] = createStore({
    get doubled() {
      return props.value * 2;
    },
    get label() {
      return `Value is ${props.value}`;
    },
  });

  return <p>{store.label} — doubled: {store.doubled}</p>;
}
```

Do not use `createMemo` for prop derivation; the getter pattern is preferred.

### Effects

```tsx
import { createEffect } from "solid-js";

createEffect(() => {
  console.log("value:", value()); // automatically tracks `value`
});
```

### Stores for complex state

```tsx
import { createStore } from "solid-js/store";

const [state, setState] = createStore({ user: { name: "", age: 0 } });

setState("user", "name", "Alice");
setState("user", (u) => ({ ...u, age: 30 }));
```

### Async data

```tsx
import { createResource, Suspense } from "solid-js";

const [user] = createResource(() => props.id, (id) => fetch(`/api/users/${id}`).then(r => r.json()));

<Suspense fallback={<p>Loading…</p>}>
  <p>{user()?.name}</p>
</Suspense>
```

Prefer `@solid-primitives/fetch` (see below) over manual `createResource` + `fetch`.

### Control flow

Always use SolidJS control-flow components, not ternaries:

```tsx
import { Show, For, Switch, Match } from "solid-js";

<Show when={isLoggedIn()} fallback={<Login />}><Dashboard /></Show>

<For each={items()}>{(item) => <li>{item.name}</li>}</For>

<Switch>
  <Match when={status() === "loading"}><Spinner /></Match>
  <Match when={status() === "error"}><ErrorView /></Match>
  <Match when={status() === "ready"}><Content /></Match>
</Switch>
```

For lists where identity matters, use `@solid-primitives/keyed`'s `Key` component instead of `For`.

### Error boundaries

```tsx
import { ErrorBoundary } from "solid-js";

<ErrorBoundary fallback={(err, reset) => (
  <div><p>{err.message}</p><button onClick={reset}>Retry</button></div>
)}>
  <RiskyComponent />
</ErrorBoundary>
```

---

## 4. solid-primitives

Prefer `@solid-primitives/*` packages over manual implementations. Install individually (e.g. `npm i @solid-primitives/fetch`).

| Package | Use instead of | What it provides |
|---|---|---|
| `@solid-primitives/fetch` | `createResource` + `fetch` | `createFetch` — reactive fetch with loading/error states |
| `@solid-primitives/storage` | `localStorage` calls | `createLocalStorage`, `createSessionStorage` — reactive storage |
| `@solid-primitives/event-listener` | `addEventListener` in effects | `createEventListener(target, event, handler)` — auto-cleans up |
| `@solid-primitives/scheduled` | manual debounce/throttle | `debounce(fn, ms)`, `throttle(fn, ms)` |
| `@solid-primitives/timer` | `setInterval`/`setTimeout` in effects | `createTimer`, `createInterval` — auto-cleans up |
| `@solid-primitives/media` | `window.matchMedia` | `createMediaQuery("(max-width: 768px)")` — reactive |
| `@solid-primitives/resize-observer` | `ResizeObserver` in effects | `createResizeObserver(el, callback)` — auto-cleans up |
| `@solid-primitives/memo` | `createMemo` for heavy/async work | `createLazyMemo`, `createAsyncMemo` |
| `@solid-primitives/keyed` | `For` when items have stable identity | `Key` component — stable DOM nodes keyed by value |

### Examples

```tsx
// Fetch
import { createFetch } from "@solid-primitives/fetch";
const [data] = createFetch<User>(`/api/users/${props.id}`);

// Storage
import { createLocalStorage } from "@solid-primitives/storage";
const [store, setStore] = createLocalStorage();
setStore("theme", "dark");

// Debounced search
import { debounce } from "@solid-primitives/scheduled";
const search = debounce((q: string) => fetchResults(q), 300);

// Interval
import { createInterval } from "@solid-primitives/timer";
createInterval(() => refetch(), 5000); // stops automatically on cleanup

// Media query
import { createMediaQuery } from "@solid-primitives/media";
const isMobile = createMediaQuery("(max-width: 768px)");
<Show when={isMobile()}><MobileNav /></Show>

// Keyed list
import { Key } from "@solid-primitives/keyed";
<Key each={items()} by="id">{(item) => <Row item={item()} />}</Key>
```
