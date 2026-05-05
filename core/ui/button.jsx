import { forwardRef } from "react";

/**
 * @typedef {"black" | "white"} ButtonColor
 *
 * @typedef {import("react").ButtonHTMLAttributes<HTMLButtonElement> & {
 *   color?: ButtonColor;
 * }} ButtonProps
 */

const Button = forwardRef(function Button(
  /** @type {ButtonProps} */ { children, color = "black", type = "button", ...props },
  /** @type {import("react").ForwardedRef<HTMLButtonElement>} */ ref
) {
  const className =
    color === "white"
      ? "px-4 py-2 rounded-md bg-white text-black"
      : "px-4 py-2 rounded-md bg-black text-white";

  return (
    <button
      ref={ref}
      type={type}
      className={className}
      {...props}
    >
      {children}
    </button>
  );
});

export default Button;
