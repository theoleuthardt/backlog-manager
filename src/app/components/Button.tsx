import React from "react";

export interface ButtonProps {
    text: string;
    link: string;
}


export const Button = (props: ButtonProps) => {
    return (
        <div
            className=" w-28 h-10 border-2 border-white rounded-full flex justify-center items-center
            hover:underline hover:bg-white hover:text-black"
        >
            <button>
                <a href={`${props.link}`}>{props.text}</a>
            </button>
        </div>
    );
};
