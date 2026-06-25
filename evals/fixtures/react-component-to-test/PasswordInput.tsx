import { useState } from "react";

export interface PasswordInputProps {
  /** Called with the current value on every change. */
  onChange: (value: string) => void;
  /** Minimum length before the field is considered valid. */
  minLength?: number;
}

/**
 * A password field with a show/hide toggle and an inline "too short" hint.
 * Observable behavior: typing reports the value; the toggle reveals/masks the
 * input; a hint appears while the value is below minLength.
 */
export function PasswordInput({ onChange, minLength = 8 }: PasswordInputProps) {
  const [value, setValue] = useState("");
  const [revealed, setRevealed] = useState(false);

  const tooShort = value.length > 0 && value.length < minLength;

  return (
    <div>
      <label htmlFor="pw">Password</label>
      <input
        id="pw"
        type={revealed ? "text" : "password"}
        value={value}
        onChange={(e) => {
          setValue(e.target.value);
          onChange(e.target.value);
        }}
      />
      <button type="button" onClick={() => setRevealed((r) => !r)}>
        {revealed ? "Hide" : "Show"}
      </button>
      {tooShort && <p role="alert">Password must be at least {minLength} characters.</p>}
    </div>
  );
}
