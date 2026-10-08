# Requirements

Source comments throughout this codebase cite requirement ids: `US-036`,
`US-004` and so on, and occasionally a task number. This is where they
resolve.

The full stories, with acceptance criteria, and the delivery plan they were
built from are not in this repository. They are internal planning artefacts
that describe the order the app was written in and who owned which file, which
is history rather than instruction: nothing in them tells a contributor what to
do today. What they are useful for is answering "why does the code do this?",
and the one-line summaries below carry enough of that to follow the comments.

A "task N" mention refers to the same planning material. Read it as "the batch
of work that introduced this", not as a file you are expected to find.

If a comment cites a requirement and the code no longer matches it, the code is
what ships: say so in an issue and it will get fixed in one place or the other.

## Onboarding and configuration

- **US-001**: Configure the API key and VIN from the phone
- **US-002**: Understand what is wrong when configuration fails
- **US-003**: Learn how to create a key
- **US-004**: Be warned before the key expires
- **US-005**: Set my temperature unit
- **US-006**: Enter an optional S-PIN, knowing the trade-off
- **US-007**: Clear my data

## Vehicle status

- **US-008**: See the state of my car at a glance
- **US-009**: Know how old the information is
- **US-010**: Check whether the car is locked
- **US-011**: See odometer and fuel status
- **US-012**: Refresh on demand and see what it costs
- **US-013**: Still see something when the phone is away
- **US-014**: Only be offered what my car can do
- **US-015**: Get partial data without an error

## Climate

- **US-016**: Start the air conditioning
- **US-017**: Stop the air conditioning
- **US-018**: Choose my target temperature
- **US-019**: See whether the windows are being de-iced
- **US-020**: Start and stop active ventilation
- **US-021**: Start and stop the auxiliary heater

## Charging

- **US-022**: Start and stop charging
- **US-023**: See the details of the current session
- **US-024**: Set the charge limit
- **US-025**: Change the charge mode
- **US-026**: Look at my charging profiles and timers
- **US-027**: Edit a charging profile

## Find my car

- **US-028**: See where the car is parked
- **US-029**: Know how far away it is and in which direction
- **US-030**: See the car on a map
- **US-031**: Explore the map around the car
- **US-032**: Navigate to the car
- **US-033**: Handle a car that has no position

## Fast access

- **US-034**: See my car's state in the glance carousel
- **US-035**: Go straight from the glance into the actions
- **US-036**: Land on the controls, not on a status page
- **US-037**: Trigger my most-used action in one press
- **US-038**: Show my car's state on my own watch face
- **US-039**: Learn how to reach the app in two presses
- **US-061**: Put the controls in my own order

## Reliability and quota

- **US-040**: Track and respect the request quota
- **US-041**: Keep the last known state
- **US-042**: Get the request options right
- **US-043**: Understand what happened after sending a command (since 1.2.0 one check of the car 15 s after it, see decisions.md "One check after a command")
- **US-044**: Read errors in plain language
- **US-045**: Know when my phone is the problem
- **US-046**: Never poll (the one check after a command is caused by the user's command and can be switched off)
- **US-062**: Confirm only what deserves confirming

## Developer experience

- **US-047**: Generate the mock from the OpenAPI contract
- **US-048**: Reject everything the real server rejects
- **US-049**: Reproduce the real response shapes exactly
- **US-050**: Simulate the failures I cannot trigger on demand
- **US-051**: Serve the mock over HTTPS
- **US-052**: Prove the mock still matches the contract
- **US-053**: Unit-test the things that actually broke
- **US-054**: Start everything with one command
- **US-055**: Catch regressions automatically

## Branding and design

- **US-056**: Have our own icon
- **US-057**: Name and describe the app honestly
- **US-058**: Be readable on the actual display
- **US-059**: Recognise states without reading
- **US-060**: Work for users who cannot rely on colour
