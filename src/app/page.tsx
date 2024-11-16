import {Navbar} from "@components/Navbar";
import Starfield from "@components/Starfield";

export default function Home() {
  return (
    <div className="items-center justify-items-center min-h-screen">
      <Starfield
          starCount={1000}
          starColor={[255, 255, 255]}
          speedFactor={0.05}
          backgroundColor="black"
      />
        <div className="pt-3 max-w-screen-xl">
            <Navbar />
        </div>
    </div>
  );
}
