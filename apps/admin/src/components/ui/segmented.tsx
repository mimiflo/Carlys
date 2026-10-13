/**
 * Un choix exclusif présenté en segments. Ce sont de VRAIS boutons radio,
 * visuellement masqués : le clavier (flèches), les lecteurs d'écran et les
 * tests les trouvent par leur rôle, et la pastille glisse sous le libellé
 * choisi.
 */
export function Segmented<T extends string>({
  legend,
  name,
  options,
  value,
  onChange,
}: {
  legend: string;
  name: string;
  options: ReadonlyArray<{ value: T; label: string }>;
  value: T;
  onChange: (value: T) => void;
}) {
  const index = Math.max(
    0,
    options.findIndex((option) => option.value === value),
  );
  return (
    <fieldset>
      <legend className="sr-only">{legend}</legend>
      <div
        className="relative grid h-9 rounded-lg bg-surface-alt p-1 text-sm"
        style={{ gridTemplateColumns: `repeat(${options.length}, minmax(0, 1fr))` }}
      >
        <span
          aria-hidden
          className="absolute inset-y-1 left-1 rounded-md bg-surface shadow-sm ring-1 ring-border transition-transform duration-250 ease-in-out"
          style={{
            width: `calc((100% - 0.5rem) / ${options.length})`,
            transform: `translateX(${index * 100}%)`,
          }}
        />
        {options.map((option) => (
          <label
            key={option.value}
            className={`relative z-10 flex cursor-pointer items-center justify-center rounded-md px-3 font-medium transition-colors duration-150 has-[:focus-visible]:outline-2 has-[:focus-visible]:outline-primary ${
              option.value === value ? 'text-foreground' : 'text-muted hover:text-foreground'
            }`}
          >
            <input
              type="radio"
              name={name}
              value={option.value}
              checked={option.value === value}
              onChange={() => onChange(option.value)}
              className="sr-only"
            />
            {option.label}
          </label>
        ))}
      </div>
    </fieldset>
  );
}
