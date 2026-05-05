import * as React from "react";

export type ButtonColor = "black" | "white";

export type ButtonProps = React.ButtonHTMLAttributes<HTMLButtonElement> & {
  color?: ButtonColor;
};

declare const Button: React.ForwardRefExoticComponent<
  ButtonProps & React.RefAttributes<HTMLButtonElement>
>;

export default Button;
