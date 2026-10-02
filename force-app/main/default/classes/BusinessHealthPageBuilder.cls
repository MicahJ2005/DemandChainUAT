/**
 * @group BusinessHealth
 *
 * @description One Business Health page (Leadership, Sales & Pipeline, ...). Builders
 * are registered by key in BusinessHealthController.BUILDERS.
 */
public interface BusinessHealthPageBuilder {
    BusinessHealthModel.HealthPage build(BusinessHealthContext ctx);
}
