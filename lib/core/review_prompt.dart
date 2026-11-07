/// How many different days must have entries before the App Store review
/// prompt is shown.
const reviewPromptLoggedDays = 7;

/// Whether to ask for an App Store review now. Asked once ever, and only
/// right after the user logged something ([justLogged]), so it never follows
/// an error or interrupts a launch. [loggedDays] is how many different days
/// have entries.
bool shouldAskForReview({
  required int loggedDays,
  required bool alreadyAsked,
  required bool justLogged,
}) => !alreadyAsked && justLogged && loggedDays >= reviewPromptLoggedDays;
