import Button from "@/core/ui/button";

export default function Home() {
  return (
    <main className="flex w-full min-h-[calc(100dvh-4rem)] flex-col items-center justify-center gap-4">
      <span>Hello World</span>
      <Button color="black">Black Button</Button>
      <Button color="white">White Button</Button>
    </main>
  );
}
