import {Button} from "@components/Button";

export const Navbar = () => {
    return (
        <div
            className="w-screen h-20 text-xl text-white border-2 border-white rounded-full
            flex items-center justify-center max-w-screen-xl"
        >
            <div className="pr-4">
                <Button text="home" link="http://localhost:3000"/>
            </div>
            <div className="">
                <Button text="manager" link="http://localhost:3000/manager"/>
            </div>
        </div>
    );
};
