"use client";
import React from "react";
import { Slider } from "~/components/ui/slider";
import type { UniSliderProps } from "~/app/types";

export const UniSlider = (props: UniSliderProps) => {
  return (
    <div id="slider" className={`mb-4 h-[2rem] text-center ${props.className}`}>
      <Slider
        ref={props.ref}
        className="invert"
        defaultValue={[props.defaultValue]}
        max={props.maxvalue}
        step={props.step}
      />
    </div>
  );
};
