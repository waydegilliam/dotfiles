# TypeScript Standards

Use the relevant sections for TypeScript and JavaScript code, including standalone files and snippets. Apply React,
data-fetching, and styling rules only when the code uses those tools. Follow the framework's rules and existing code.

- Follow any existing TypeScript, lint, and formatter configuration, including indentation, semicolons, quotes,
  and line length. Without configuration, follow nearby style or language conventions and the intended runtime.
- Prefer named exports unless a framework or established project convention requires default exports.
- When an API or event schema changes, run the project's configured type-generation task if it has one. Update the
  source schema rather than editing generated types by hand.

## React

- Import hooks directly instead of through the `React` namespace where consistent with the project.
- Reuse existing components before creating new ones. Check the component library, related feature code, and any
  component registry the project already uses.
- Prefer function declarations for components and `interface` for props unless the project follows another convention.
- Destructure props in the function signature.
- Extend or adapt child component prop types instead of duplicating them when possible.
- Use the project's icon library, naming rules, and existing logos. Add new icons and logos in the same way as existing
  ones instead of loading them from an external image URL.

### Reading and Updating Data

- Follow the project's approach to fetching data. Choose where to fetch based on routing, rendering, caching, and
  whether the data is available only on the server.
- Use the existing query library and typed client for server data used in React. Let them handle loading, errors,
  caching, and avoiding duplicate requests.
- Use the query library's mutations for writes when the UI needs their pending, error, or success state. Refresh or
  update cached data after a change so related views stay in sync.
- Reuse query keys and options. When a route needs data before rendering, use the project's loader or prefetch pattern
  and consume the same query from the component.
- Call the client directly for streaming, downloads, or other work that does not benefit from the query library.

### SSR and Hydration

- Follow the framework's rendering defaults and the project's route conventions. Change server-rendering behavior
  only for a concrete requirement.
- Make the server and client produce the same HTML on the first render. Use loaders, effects, or event handlers for
  current times, random values, and browser-only data. Share any initial values between server and client.
- Prefer responsive CSS for layout. If JavaScript needs the screen size, use an existing hook that handles hydration
  or start with the same value on the server and client, then update it after mount.
- Reuse the project's date-formatting helpers and timezone context. Ensure server and client use the same locale and
  timezone for initially rendered dates.

### Component Organization and Reuse

- Keep feature components with their feature and shared UI components in the existing UI library. Keep components
  that need app-specific data or services with that app.
- Prefer one main component per file. A small component used only in that file can sit above the component that uses it.
- Follow the project's file naming and export rules. Add re-export files only when needed.
- Keep components focused and within the project's file-size limits. Split large components by purpose instead of
  adding lint exceptions.
- Use existing buttons, links, inputs, and overlays where available. Preserve their accessibility, routing, loading,
  and disabled-state behavior instead of rebuilding it in feature code.
- Import components, hooks, and helpers through the library's supported import paths. Follow project rules for imports
  from internal files, shared export files, and underlying UI libraries.
- Combine or extend existing components before adding new ones. When none fits, use the right HTML elements and
  preserve keyboard controls, focus behavior, and accessible names.

### Selects and Editable Fields

- Use a select for a short fixed list and a searchable combobox for a long list. Use a control with explicit support
  for multiple values when multiple selection is required.
- Reuse existing selection components instead of assembling a new popover and command-list wrapper for each feature.
- Use the right field component for when data is saved: on form submission or after each inline edit. Follow its
  validation rules.
- Reuse feature-specific field components that already handle saving, notifications, or building requests.
  Reject unsupported choices instead of replacing them with made-up values.

## Tailwind and CSS

- Follow the project's styling system. When using Tailwind, prefer `size-*` over paired `w-*` and `h-*` utilities when
  supported and width and height match.
- Reuse existing variants, utilities, and class-merging helpers instead of defining duplicate styles.
- Name variables and props containing CSS classes with a `className` suffix, such as `containerClassName`, where this
  fits the framework's conventions.
- Use the design system's named colors and styles for text, backgrounds, borders, status, focus, and other states.
- Use the preferred token name when several names mean the same thing. Follow the styling rules for feature code
  and the component library.
- Use raw colors only for category colors or third-party branding when the design system allows them.
- Keep existing lint exceptions only while needed. As you fix old issues, update or remove their exceptions using
  the project's tools. Do not add exceptions for new code.

## Testing

- Use existing test tools and file conventions when available.
- Test pure logic with unit tests. Test components and hooks with the project's rendering test tools.
- Use the project's visual testing or component preview setup for layout, themes, and visual states when available.
- Run the narrowest relevant checks, using documented commands when available. For standalone code, use suitable
  checks supported by the available tooling without requiring a project test setup.
