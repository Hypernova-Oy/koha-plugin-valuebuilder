function mfw_vb_valuebuilder(frameworkcode, fieldcode, subfieldcode, trigger) {
  let input = mfw_vb_get_item_subfield_input_element(frameworkcode, fieldcode, subfieldcode);

  var itemtype = document.getElementById("subfield952y").querySelector("select").value;
  var branchcode = document.getElementById("subfield952a").querySelector("select").value;
  var biblionumber = document.getElementsByName("biblionumber")[0].value;
  var url = '/api/v1/contrib/hypernova/catalogue/valuebuilder'
  + '?frameworkcode=' + frameworkcode
  + '&fieldcode=' + fieldcode
  + '&subfieldcode=' + subfieldcode
  + '&itemtype=' + itemtype
  + '&branchcode=' + branchcode
  + '&biblionumber=' + biblionumber;

  fetch(url)
  .then(response => response.json())
  .then(data => {
    if (data.value) {
      if (input.tagName === 'SELECT') {
        let option = input.querySelector('option[value="'+data.value+'"]')
        if (option) {
          option.selected = true;
        }
        else {
          console.log(`Plugin::Fi::Hypernova::ValueBuilder:> Subfield='${fieldcode}$${subfieldcode}' FW='${frameworkcode}' value='${data.value}' not a valid option in the dropdown list`);
          alert(`Plugin::Fi::Hypernova::ValueBuilder:> Subfield='${fieldcode}$${subfieldcode}' FW='${frameworkcode}' value='${data.value}' not a valid option in the dropdown list`);
        }
        input.value = data.value;
        input.dispatchEvent(new Event('change'));
      }
      else if (input.tagName === 'INPUT') {
        input.value = data.value;
        input.dispatchEvent(new Event('change'));
      }
    }
    else {
      throw Error(data.error);
    }
  })
  .catch(error => {
    console.log(error);
    alert('Error: '+error);
  })
  .finally(() => {
    if (trigger === "onsave") {
      mfw_vb_maybe_do_form_submit(trigger);
    }
  });
}

let formSubmissionValueBuildersWaitingToComplete = 0; // Keep track of onsave-triggered valuebuilders that are waiting for the fetch to complete
let formSubmissionTriggeringEvent; // We need to redispatch the same event from the same element, because there are multiple submit-buttons having a bit different behaviour.
function mfw_vb_bind_valuebuilder(frameworkcode, fieldcode, subfieldcode, trigger) {
  let subfield_line = document.getElementById('subfield'+fieldcode+subfieldcode);
  if (!subfield_line) {
    console.log(`Plugin::Fi::Hypernova::ValueBuilder:> Subfield='${fieldcode}$${subfieldcode}' FW='${frameworkcode}' has a ValueBuilder defined but subfield not found`);
    return;
  }

  let input = mfw_vb_get_item_subfield_input_element(frameworkcode, fieldcode, subfieldcode);

  if (trigger === "disabled") {
    return;
  }
  else if (trigger === "prefill") {
    let addingNewItem = document.getElementById('f').querySelector('input[name="op"][value="cud-additem"]');
    if (addingNewItem && input && ! input.value) {
      mfw_vb_valuebuilder(frameworkcode, fieldcode, subfieldcode, trigger);
    }
  }
  else if (trigger === "onsave") {
    let formSubmitButtons = document.querySelectorAll('#cataloguing_additem_newitem input[type="submit"]');
    for (let formButton of formSubmitButtons) {
      formButton.addEventListener('click', function(event) {
        formSubmissionTriggeringEvent = event;
        if (formSubmissionValueBuildersWaitingToComplete > 0) {
          event.preventDefault();
          if (input.value) {
            // Prevent fetching the ValueBuilder value if the input is already filled
            mfw_vb_maybe_do_form_submit(trigger);
            return;
          }
          mfw_vb_valuebuilder(frameworkcode, fieldcode, subfieldcode, trigger);
        }
        return true;
      });
    }
    formSubmissionValueBuildersWaitingToComplete++;
  }
  else if (trigger === "triggered") {
    // Do nothing
  }
  let trigger_button = document.createElement('span');
  trigger_button.innerHTML = '<i class="fa fa-lg fa-gear"></i>';
  trigger_button.classList.add('mfw_vb_trigger_button');
  subfield_line.appendChild(trigger_button);
  trigger_button.addEventListener('click', function() {
    mfw_vb_valuebuilder(frameworkcode, fieldcode, subfieldcode, "triggered");
  });
}

function mfw_vb_get_item_subfield_input_element(frameworkcode, fieldcode, subfieldcode) {
  let subfield_line = document.getElementById('subfield'+fieldcode+subfieldcode);
  if (!subfield_line) {
    console.log(`Plugin::Fi::Hypernova::ValueBuilder:> Subfield='${fieldcode}$${subfieldcode}' FW='${frameworkcode}' has a ValueBuilder defined but subfield not found`);
    return;
  }

  let input = subfield_line.querySelector(".input_marceditor");
  if (!input) {
    console.log(`Plugin::Fi::Hypernova::ValueBuilder:> Subfield='${fieldcode}$${subfieldcode}' FW='${frameworkcode}' has a ValueBuilder defined but input not found`);
    return;
  }
  return input;
}

function mfw_vb_maybe_do_form_submit(trigger) {
  if (trigger === "onsave") {
    formSubmissionValueBuildersWaitingToComplete--;
    if (formSubmissionValueBuildersWaitingToComplete <= 0) {
      formSubmissionTriggeringEvent.target.dispatchEvent(
        new MouseEvent(formSubmissionTriggeringEvent.type)
      );
    }
  }
}