import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/health_connection_controller.dart';
import '../providers/health_providers.dart';

/// Importe les pesées de la balance à l'OUVERTURE de l'écran qu'il enrobe
/// (Progrès), au RETOUR AU PREMIER PLAN, et dès que la connexion s'active.
///
/// Rien ne s'affiche : une pesée importée apparaît dans la liste, et
/// l'import lui-même se borne à un passage par quart d'heure
/// (`ImportHealthWeighings.minInterval`).
class HealthImportTrigger extends ConsumerStatefulWidget {
  const HealthImportTrigger({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<HealthImportTrigger> createState() =>
      _HealthImportTriggerState();
}

class _HealthImportTriggerState extends ConsumerState<HealthImportTrigger> {
  late final AppLifecycleListener _lifecycle;

  void _import() => ref.read(healthWeighingImportProvider).run();

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _import);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _import();
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(healthConnectionProvider, (previous, next) {
      // `was == false` : une connexion qui S'ACTIVE, pas la première lecture
      // (que l'import d'ouverture couvre déjà).
      final was = previous?.valueOrNull?.connected;
      if (was == false && (next.valueOrNull?.connected ?? false)) _import();
    });
    return widget.child;
  }
}
