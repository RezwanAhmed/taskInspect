import 'package:flutter/material.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';

/// Icon and short name for each kind of requirement.
abstract final class RequirementTypeLook {
  static IconData icon(RequirementType type) => switch (type) {
        RequirementType.checkbox => Icons.check_box_outlined,
        RequirementType.yesNo => Icons.rule,
        RequirementType.text => Icons.notes,
        RequirementType.number => Icons.pin_outlined,
        RequirementType.dropdown => Icons.arrow_drop_down_circle_outlined,
        RequirementType.multipleSelection => Icons.checklist,
        RequirementType.photo => Icons.photo_camera_outlined,
        RequirementType.document => Icons.picture_as_pdf_outlined,
        RequirementType.comment => Icons.comment_outlined,
      };

  static String label(RequirementType type) => switch (type) {
        RequirementType.checkbox => 'Checkbox',
        RequirementType.yesNo => 'Yes / No',
        RequirementType.text => 'Text',
        RequirementType.number => 'Number',
        RequirementType.dropdown => 'Choose one',
        RequirementType.multipleSelection => 'Choose any',
        RequirementType.photo => 'Photo',
        RequirementType.document => 'PDF document',
        RequirementType.comment => 'Comment',
      };
}
