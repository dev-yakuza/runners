extension Kernel (Polyfill)
  def abort: (String) -> void
  def exit: (Integer) -> void
  def system: (*String, exception: bool) -> void
  def load: (String) -> bool
  def __method__: -> Symbol?
  def __dir__: -> String
  def Array: (any) -> Array<any>
  def Pathname: (String | Pathname) -> Pathname
end
