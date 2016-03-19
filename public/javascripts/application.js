$(document).ready(function() {
  $("form.delete").submit(function(event) {
    // Stops the form from default behavior.
    event.preventDefault();
    event.stopPropagation();
    var ok = confirm("Are you sure? This cannot be undone!");
    if (ok) {
      this.submit();
    }
  });
});