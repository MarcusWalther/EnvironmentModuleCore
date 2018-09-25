namespace EnvironmentModules
{
    /// <summary>
    /// This enum defines all types that Environment Modules can have.
    /// </summary>
    public enum EnvironmentModuleType
    {
        /// <summary>
        /// The module is a common module that has dependencies and provides functions etc.
        /// </summary>
        Default,
        /// <summary>
        /// The module is used to load any concrete (default) module with the same name. This type is used by automatically generated modules.
        /// </summary>
        Meta,
        /// <summary>
        /// This module does provide functions, aliases etc, but can only be loaded by a default module as dependency.
        /// </summary>
        Abstract
    }

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
