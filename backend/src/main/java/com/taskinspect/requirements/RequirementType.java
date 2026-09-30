package com.taskinspect.requirements;

/** How a requirement is answered (spec section 5, plus DOCUMENT for PDFs). */
public enum RequirementType {

    CHECKBOX,
    YES_NO,
    TEXT,
    NUMBER,
    DROPDOWN,
    MULTIPLE_SELECTION,
    PHOTO,
    DOCUMENT,
    COMMENT;

    /** Dropdown and multiple selection offer a list of options. */
    public boolean hasOptions() {
        return this == DROPDOWN || this == MULTIPLE_SELECTION;
    }

}
