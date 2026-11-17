import { Controller } from "@hotwired/stimulus";

// Masks a hidden transaction's name, merchant and amount on its owner's screen
// until they click the eye. Other members never receive these values.
export default class extends Controller {
  static targets = ["masked", "revealed", "revealButton", "concealButton"];

  toggle(event) {
    event.preventDefault();
    const revealing = this.revealedTargets.some((el) =>
      el.classList.contains("hidden"),
    );

    this.revealedTargets.forEach((el) => {
      el.classList.toggle("hidden", !revealing);
    });
    this.maskedTargets.forEach((el) => {
      el.classList.toggle("hidden", revealing);
    });
    this.revealButtonTargets.forEach((el) => {
      el.classList.toggle("hidden", revealing);
    });
    this.concealButtonTargets.forEach((el) => {
      el.classList.toggle("hidden", !revealing);
    });
  }
}
