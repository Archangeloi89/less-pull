# Night Shift and warmth

Night Shift is the macOS feature that warms the screen in the evening. Extra Warmth is Less Pull's own slider, which can go further, through amber to red. The two are separate, and Less Pull can tie them together if you want.

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/nightshift-dark.svg">
    <img src="assets/nightshift-light.svg" width="100%" alt="Timeline of one example day. Night Shift is on from 22:00 to 07:00. Extra Warmth, when it follows Night Shift, is 0 percent by day and returns to your saved amount at night. Grayscale stays as you set it, day and night.">
  </picture>
</p>

<sub>Example schedule. Night Shift keeps the schedule you set in macOS.</sub>

## Extra Warmth follows Night Shift

With this option on:

- While Night Shift is off, the Extra Warmth you inherit from your global setting is removed.
- When Night Shift turns on, your saved amount comes back.
- Grayscale is not affected. It stays the way you set it, day and night.
- Apps and websites with their own warmth keep it.

With the option off, Extra Warmth stays wherever you put the slider, at any time of day. In short: on means Extra Warmth only while Night Shift is on and none in the daytime; off means Extra Warmth stays on all day.

## Changing warmth while following

If you move the slider while following is on, your change applies right away and overrides following for the moment. It is also saved as your amount for the night. The override ends when Night Shift next turns on or off, or when you choose **Resume Following**. Following itself stays on throughout.

Turning Grayscale on or off does not start an override.

## Controlling Night Shift from Less Pull

- The **Night Shift** entry in the menu holds everything: **Turn On / Turn Off** switches Night Shift now, and your macOS schedule is kept and may change the state later.
- **Off for 1 hour**, **Off for 4 hours** and **Off until morning** pause it. When the pause ends, Night Shift resumes only if your schedule says it should be on. It is never forced on in the daytime.
- A timed pause wins over an app rule that says Night Shift: On.
- Quitting Less Pull removes the warmth it added and ends a timed pause safely.
- **Pause Less Pull** is different: it shows the plain display for a while and leaves Night Shift alone.

## Limits

- The Extra Warmth percentage is a relative control. It is not a Kelvin value and not a measured reduction in blue light.
- Some displays, HDR modes and other display tools can stop Night Shift from taking effect. **Settings… → About → Diagnostics…** shows what Less Pull requested and what macOS reported.
- Less Pull is not a medical device and makes no promises about sleep or eye health.
