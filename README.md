# zeleste

The first two levels of [Celeste](https://en.wikipedia.org/wiki/Celeste_(video_game)), but on a Game Boy Advance.

You can play it online here: [braheezy.github.io/zeleste-web](https://braheezy.github.io/zeleste-web/).

## how

I'd call this a demake but I didn't actually demake much. 

Naturally, there are a lot of data assets in a game. I'm not comfortable publicly hosting all these assets because of licensing so they are in private repository `zeleste-assets`. Most of the content in `tools` is about processing this data for the ROM to use.

There are several interactive HTML tools that are critical in annotating and processing the data into something useful for the ROM and the Taskfile helps launch them. 

### backgrounds
Backgrounds for levels were pulled from https://berrycamp.github.io/. The PNGs are cut into 8x8 pixel tiles, de-duplicated, and analyzed for color to pick palettes. They use `BG0` drawing mode on the GBA so it's efficient and has high parity. Celeste's natural resolution is 320x180 pixels, bigger than the 240x160 the GBA has, so this version has more camera scrolling going on.

Backgrounds contain all the colliions, hazards, pits, and foreground elements too. These are managed and annotated with:

    task collision

### sprites

The player sprites for madeline, as well as all NPCs and collectibles, were taken from online sources made available by the rich Celeste modding scene. These were already an appropriate size for GBA. It was mostly about finding them, assigning them to uses in gameplay, and packing spritesheets.

### Madeline's hair

In the original game, the madeline sprites are bald and the hair drawn procedurally. This GBA version does the same. The logic explained by [Noel here](https://www.reddit.com/r/gamedev/comments/9a0cfr/how_is_the_hair_in_celeste_made/) was very useful. 

For sprite animations, sometimes hair needs to be shifted one or two pixels to maintain alignment, like when Madeline turns her head. This can be managed with:

    task hair


### music

Background music are true `.xm` tracker files. This was done by running another project of mine `wav2xm`, that, as the name implies, tries to create XM files from the audio waves stored in WAV files. This is an extremely lossy process so it's not perfect, but I think it sounds quite good.

Sound effects, like footfalls, are raw WAVs the GBA can play as-is.

### gameplay logic

I have never seen the source code for Celeste but I have played it a bunch. There is also prior art that was quite helpful:

- https://github.com/NoelFB/Celeste.git
- https://github.com/EXOK/Celeste2.git
- https://github.com/EXOK/Celeste64.git
- https://github.com/iProgramMC/CelesteNES.git
- https://github.com/IsaGoodFriend/Celeste-For-GBA.git


## disclaimer and licensing

This is an unofficial, non-commercial fan project. It is not affiliated with, endorsed by, or sponsored by Extremely OK Games, Maddy Makes Games, or the Celeste team.

Celeste, Madeline, related characters, artwork, music, sound effects, dialogue, level designs, and other Celeste IP belong to their respective owners. No license is granted here for Celeste IP or third-party assets.

Original source code written for this demake is intended to be released under the MIT license. That does not apply to the private asset repository, generated asset blobs, ROM files, save files, or any Celeste-derived material.

Celeste was created by Maddy Thorson and Noel Berry. Celeste is owned by Extremely OK Games / Maddy Makes Games.

## building

This public repo expects a private asset checkout next to it:

```text
celeste-demake/
  zeleste/
  zeleste-assets/
```

Inside `zeleste`, `assets` should point at that private asset directory:

```sh
ln -s ../zeleste-assets assets
```

Generate everything and build the ROM:

```sh
zig build
```

The ROM is written to:

```text
zig-out/zeleste.gba
```

Useful commands:

```sh
# Hardcodes path to mGBA on Mac
zig build run
zig build run -- 0 -1
zig build -Ddev-hud=true
```

`zig build run` builds and opens the ROM in mGBA. Passing two arguments after `--` starts from a specific chapter and room for development.
