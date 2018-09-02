namespace EnvironmentModules
{
    /// <summary>
    /// This enum defines all types that Environment Modules can have.
    /// </summary>
    public enum EnvironmentModuleType { Default, Meta, Abstract }

    public class EnvironmentModuleInfoBase
    {
        /// <summary>
        /// The full name of the module. This name can be used to load the module with the help of the powershell-environment.
        /// </summary>
        public string FullName { get; set; }

        /// <summary>
        /// Specifies the type of the module.
        /// </summary>
        public EnvironmentModuleType ModuleType { get; set; }

        public EnvironmentModuleInfoBase(string fullName, EnvironmentModuleType moduleType = EnvironmentModuleType.Default)
        {
            FullName = fullName;
            ModuleType = moduleType;
        }
    }
}
